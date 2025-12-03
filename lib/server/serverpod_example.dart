/// Example Serverpod endpoint for WebRTC signaling
/// Copy this as a template for your own Serverpod project

// In your Serverpod project: lib/src/endpoints/webrtc.dart

// Import the manager from webrtc_flutter_api
// import 'package:webrtc_flutter_api/server/signaling_manager.dart';

// Example implementation:
/*

import 'package:serverpod/serverpod.dart';
import 'package:webrtc_flutter_api/server/signaling_manager.dart';

// Create manager instance (or use singleton)
final webrtcManager = WebRTCSignalingManager();

// WebSocket endpoint handler
Future<void> handleWebRTCSocket(
  Session session,
  dynamic message,
) async {
  try {
    if (message is! String) return;

    final data = jsonDecode(message) as Map<String, dynamic>;
    final action = data['action'] as String?;

    // ========== Client joins room ==========
    if (action == 'join') {
      final roomId = data['roomId'] as String;
      final sessionId = data['sessionId'] as String;

      await webrtcManager.joinRoom(
        roomId: roomId,
        sessionId: sessionId,
        session: session,
        metadata: {
          'userAgent': session.httpRequest?.headers['user-agent'],
          'ip': session.remoteAddress?.address,
        },
      );

      // Send current peers to new client
      await webrtcManager.sendPeersList(
        roomId: roomId,
        sessionId: sessionId,
        sendFunction: (peerId, msg) {
          if (peerId == sessionId) {
            session.sendMessage(msg);
          }
        },
      );

      // Notify others about new peer
      await webrtcManager.notifyPeerJoined(
        roomId: roomId,
        sessionId: sessionId,
        sendFunction: (peerId, msg) {
          // Send to peer via room sessions
          final room = webrtcManager._rooms[roomId];
          if (room?[peerId] != null) {
            (room[peerId] as Session).sendMessage(msg);
          }
        },
      );

      print('✅ Client joined: $sessionId in room $roomId');
      return;
    }

    // ========== Relay WebRTC signals ==========
    if (['webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate']
        .contains(data['type'])) {
      final roomId = _getRoomForSession(session);
      if (roomId == null) {
        print('❌ Room not found for session');
        return;
      }

      await webrtcManager.relaySignal(
        roomId: roomId,
        signal: data,
        sendFunction: (peerId, msg) {
          final room = webrtcManager._rooms[roomId];
          final peerSession = room?[peerId] as Session?;
          if (peerSession != null) {
            peerSession.sendMessage(msg);
          }
        },
      );

      print('📤 Relayed ${data['type']}');
      return;
    }

    // ========== Peer leaves ==========
    if (data['type'] == 'leave_room') {
      final roomId = _getRoomForSession(session);
      final sessionId = _getSessionIdForConnection(session);

      if (roomId != null && sessionId != null) {
        await webrtcManager.notifyPeerLeft(
          roomId: roomId,
          sessionId: sessionId,
          sendFunction: (peerId, msg) {
            final room = webrtcManager._rooms[roomId];
            final peerSession = room?[peerId] as Session?;
            if (peerSession != null) {
              peerSession.sendMessage(msg);
            }
          },
        );

        await webrtcManager.leavePeer(
          roomId: roomId,
          sessionId: sessionId,
        );

        print('❌ Client left: $sessionId from room $roomId');
      }
      return;
    }
  } catch (e) {
    print('Error handling WebRTC message: $e');
  }
}

// ========== Helper functions ==========

String? _getRoomForSession(Session session) {
  for (final (roomId, peers) in webrtcManager._rooms.entries) {
    if (peers.values.contains(session)) {
      return roomId;
    }
  }
  return null;
}

String? _getSessionIdForConnection(Session session) {
  for (final (roomId, peers) in webrtcManager._rooms.entries) {
    for (final (sessionId, peerSession) in peers.entries) {
      if (peerSession == session) {
        return sessionId;
      }
    }
  }
  return null;
}

// Register endpoint in your Serverpod main.dart:
// app.webSocketEndpoint('webrtc', handleWebRTCSocket);

*/
