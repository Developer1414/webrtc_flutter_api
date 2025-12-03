/// WebRTC server-side signaling manager for Serverpod.
/// Handles relay of WebRTC signals, room management, and peer discovery.
///
/// Backend-agnostic: works with any WebSocket implementation.

import 'dart:convert';

/// Server-side WebRTC signaling manager
///
/// Easy integration:
/// ```dart
/// final manager = WebRTCSignalingManager();
///
/// // In your WebSocket handler:
/// await manager.joinRoom(
///   roomId: roomId,
///   sessionId: sessionId,
///   session: websocketSession,
/// );
///
/// // When receiving signals:
/// await manager.relaySignal(
///   roomId: roomId,
///   signal: signal,
///   sendFunction: (peerId, message) =>
///     sessions[peerId].send(message),
/// );
/// ```
class WebRTCSignalingManager {
  final Map<String, Map<String, dynamic>> _rooms = {};
  final Map<(String, String), SessionMetadata> _metadata = {};

  /// Get peers in room (excluding self)
  List<String> getPeers(String roomId, String excludeSessionId) {
    return _rooms[roomId]
            ?.keys
            .where((id) => id != excludeSessionId)
            .toList() ??
        [];
  }

  /// Get all room IDs
  List<String> getRooms() => _rooms.keys.toList();

  /// Get room size
  int getRoomSize(String roomId) => _rooms[roomId]?.length ?? 0;

  /// Check room exists
  bool roomExists(String roomId) => _rooms.containsKey(roomId);

  /// Join a room
  Future<void> joinRoom({
    required String roomId,
    required String sessionId,
    required dynamic session,
    Map<String, dynamic>? metadata,
  }) async {
    _rooms.putIfAbsent(roomId, () => {});
    _rooms[roomId]![sessionId] = session;
    _metadata[(roomId, sessionId)] = SessionMetadata(
      sessionId: sessionId,
      joinedAt: DateTime.now(),
      metadata: metadata ?? {},
    );
  }

  /// Relay signal to target peer or broadcast
  Future<void> relaySignal({
    required String roomId,
    required Map<String, dynamic> signal,
    required Function(String, String) sendFunction,
  }) async {
    final room = _rooms[roomId];
    if (room == null) return;

    try {
      final payload = signal['payload'] is String
          ? jsonDecode(signal['payload'] as String) as Map
          : signal['payload'] as Map;

      final targetPeerId = payload['targetPeerId'] as String?;
      final senderSessionId = signal['senderSessionId'] as String;
      final messageJson = jsonEncode(signal);

      if (targetPeerId != null && room.containsKey(targetPeerId)) {
        sendFunction(targetPeerId, messageJson);
        return;
      }

      room.forEach((peerId, _) {
        if (peerId != senderSessionId) {
          sendFunction(peerId, messageJson);
        }
      });
    } catch (e) {
      print('Error relaying signal: $e');
    }
  }

  /// Broadcast to all in room
  Future<void> broadcastToRoom({
    required String roomId,
    required Map<String, dynamic> message,
    required Function(String, String) sendFunction,
    String? excludeSessionId,
  }) async {
    final room = _rooms[roomId];
    if (room == null) return;

    final messageJson = jsonEncode(message);
    room.keys.forEach((peerId) {
      if (excludeSessionId == null || peerId != excludeSessionId) {
        sendFunction(peerId, messageJson);
      }
    });
  }

  /// Notify room about peer join
  Future<void> notifyPeerJoined({
    required String roomId,
    required String sessionId,
    required Function(String, String) sendFunction,
  }) async {
    final peers = getPeers(roomId, sessionId);
    await broadcastToRoom(
      roomId: roomId,
      message: {
        'type': 'peer_joined',
        'peerId': sessionId,
        'peers': peers,
      },
      sendFunction: sendFunction,
      excludeSessionId: sessionId,
    );
  }

  /// Notify room about peer leave
  Future<void> notifyPeerLeft({
    required String roomId,
    required String sessionId,
    required Function(String, String) sendFunction,
  }) async {
    await broadcastToRoom(
      roomId: roomId,
      message: {
        'type': 'peer_left',
        'peerId': sessionId,
      },
      sendFunction: sendFunction,
    );
  }

  /// Send peers list to client
  Future<void> sendPeersList({
    required String roomId,
    required String sessionId,
    required Function(String, String) sendFunction,
  }) async {
    final peers = getPeers(roomId, sessionId);
    sendFunction(
      sessionId,
      jsonEncode({
        'type': 'peers_list',
        'peers': peers,
        'roomId': roomId,
        'sessionId': sessionId,
      }),
    );
  }

  /// Remove peer from room
  Future<void> leavePeer({
    required String roomId,
    required String sessionId,
  }) async {
    _rooms[roomId]?.remove(sessionId);
    _metadata.remove((roomId, sessionId));

    if ((_rooms[roomId]?.length ?? 0) == 0) {
      _rooms.remove(roomId);
    }
  }

  /// Get session metadata
  SessionMetadata? getSessionMetadata(String roomId, String sessionId) {
    return _metadata[(roomId, sessionId)];
  }

  /// Get all room metadata
  Map<String, SessionMetadata> getRoomMetadata(String roomId) {
    final result = <String, SessionMetadata>{};
    _metadata.forEach((key, value) {
      if (key.$1 == roomId) {
        result[key.$2] = value;
      }
    });
    return result;
  }

  /// Clear room
  Future<void> clearRoom(String roomId) async {
    _rooms.remove(roomId);
    _metadata.removeWhere((key, _) => key.$1 == roomId);
  }

  /// Total active sessions
  int getTotalSessions() {
    int count = 0;
    _rooms.forEach((_, sessions) => count += sessions.length);
    return count;
  }
}

/// Session metadata
class SessionMetadata {
  final String sessionId;
  final DateTime joinedAt;
  final Map<String, dynamic> metadata;

  SessionMetadata({
    required this.sessionId,
    required this.joinedAt,
    required this.metadata,
  });

  Duration get connectionDuration => DateTime.now().difference(joinedAt);

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'joinedAt': joinedAt.toIso8601String(),
        'connectionDuration': connectionDuration.inSeconds,
        'metadata': metadata,
      };
}

/// Global singleton (or create your own instance)
final webrtcSignalingManager = WebRTCSignalingManager();
