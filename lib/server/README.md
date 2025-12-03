# WebRTC Flutter API — Server-Side Guide

This directory contains server-side signaling components for WebRTC applications built with **Serverpod**.

## Quick Start

### 1. Import the Manager

```dart
import 'package:webrtc_flutter_api/server/signaling_manager.dart';

final manager = WebRTCSignalingManager();
```

### 2. Set Up WebSocket Handler

```dart
// In your Serverpod endpoint (lib/src/endpoints/webrtc.dart)
import 'package:serverpod/serverpod.dart';
import 'package:webrtc_flutter_api/server/signaling_manager.dart';

final webrtcManager = WebRTCSignalingManager();

Future<void> handleWebRTCSocket(
  Session session,
  dynamic message,
) async {
  if (message is! String) return;
  
  final data = jsonDecode(message) as Map<String, dynamic>;
  
  // Handle join
  if (data['action'] == 'join') {
    await webrtcManager.joinRoom(
      roomId: data['roomId'],
      sessionId: data['sessionId'],
      session: session,
    );
    
    // Send peers to client
    await webrtcManager.sendPeersList(
      roomId: data['roomId'],
      sessionId: data['sessionId'],
      sendFunction: (peerId, msg) => session.sendMessage(msg),
    );
  }
  
  // Handle signals
  if (['webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate']
      .contains(data['type'])) {
    await webrtcManager.relaySignal(
      roomId: roomId,
      signal: data,
      sendFunction: (peerId, msg) {
        // Send to peer
        sessions[peerId]?.sendMessage(msg);
      },
    );
  }
  
  // Handle leave
  if (data['type'] == 'leave_room') {
    await webrtcManager.leavePeer(
      roomId: roomId,
      sessionId: sessionId,
    );
  }
}

// Register in main.dart
// app.webSocketEndpoint('webrtc', handleWebRTCSocket);
```

### 3. Register in Serverpod

```dart
// serverpod/lib/server.dart
void main() {
  // ... other setup ...
  
  app.webSocketEndpoint('webrtc', handleWebRTCSocket);
  
  // ... rest of setup ...
}
```

## API Reference

### `WebRTCSignalingManager`

#### Room Management

```dart
// Join room
await manager.joinRoom(
  roomId: 'room-123',
  sessionId: 'user-abc',
  session: websocketSession,
  metadata: {'name': 'John'},
);

// Get peers in room
List<String> peers = manager.getPeers('room-123', 'user-abc');

// Get room size
int size = manager.getRoomSize('room-123');

// Check if room exists
bool exists = manager.roomExists('room-123');

// Leave room
await manager.leavePeer(roomId: 'room-123', sessionId: 'user-abc');
```

#### Signal Relaying

```dart
// Relay signal to specific peer or broadcast
await manager.relaySignal(
  roomId: 'room-123',
  signal: {
    'type': 'webrtc_offer',
    'payload': jsonEncode({'sdp': '...', 'targetPeerId': 'user-def'}),
    'senderSessionId': 'user-abc',
  },
  sendFunction: (peerId, messageJson) {
    // Your code to send message to peer
    sessions[peerId]?.sendMessage(messageJson);
  },
);
```

#### Notifications

```dart
// Notify room about new peer
await manager.notifyPeerJoined(
  roomId: 'room-123',
  sessionId: 'user-abc',
  sendFunction: (peerId, msg) => sessions[peerId]?.sendMessage(msg),
);

// Notify room about leaving peer
await manager.notifyPeerLeft(
  roomId: 'room-123',
  sessionId: 'user-abc',
  sendFunction: (peerId, msg) => sessions[peerId]?.sendMessage(msg),
);

// Send peers list to specific client
await manager.sendPeersList(
  roomId: 'room-123',
  sessionId: 'user-abc',
  sendFunction: (peerId, msg) => sessions[peerId]?.sendMessage(msg),
);
```

#### Admin

```dart
// Get session metadata
SessionMetadata? meta = manager.getSessionMetadata('room-123', 'user-abc');

// Get all metadata in room
Map<String, SessionMetadata> allMeta = manager.getRoomMetadata('room-123');

// Get all rooms
List<String> rooms = manager.getRooms();

// Get total sessions
int total = manager.getTotalSessions();

// Clear room
await manager.clearRoom('room-123');
```

## Signal Protocol

### Client → Server

```json
// Join room
{
  "action": "join",
  "roomId": "room-123",
  "sessionId": "user-abc"
}

// WebRTC offer
{
  "type": "webrtc_offer",
  "payload": "{\"sdp\": \"...\", \"type\": \"offer\", \"targetPeerId\": \"user-def\"}",
  "senderSessionId": "user-abc"
}

// WebRTC answer
{
  "type": "webrtc_answer",
  "payload": "{\"sdp\": \"...\", \"type\": \"answer\"}",
  "senderSessionId": "user-abc"
}

// ICE candidate
{
  "type": "webrtc_ice_candidate",
  "payload": "{\"candidate\": \"...\", \"targetPeerId\": \"user-def\"}",
  "senderSessionId": "user-abc"
}

// Leave room
{
  "type": "leave_room"
}
```

### Server → Client

```json
// Peers list (after join)
{
  "type": "peers_list",
  "peers": ["user-def", "user-ghi"],
  "roomId": "room-123",
  "sessionId": "user-abc"
}

// New peer joined
{
  "type": "peer_joined",
  "peerId": "user-xyz",
  "peers": ["user-def", "user-ghi", "user-xyz"]
}

// Peer left
{
  "type": "peer_left",
  "peerId": "user-def"
}

// Relayed signal (offer/answer/ICE)
{
  "type": "webrtc_offer",
  "payload": "{\"sdp\": \"...\", \"type\": \"offer\"}",
  "senderSessionId": "user-abc"
}
```

## Customization

### Custom Session Metadata

```dart
await manager.joinRoom(
  roomId: 'room-123',
  sessionId: 'user-abc',
  session: session,
  metadata: {
    'name': 'John Doe',
    'avatar': 'https://...',
    'role': 'admin',
  },
);

// Later, retrieve metadata
final meta = manager.getSessionMetadata('room-123', 'user-abc');
print(meta?.metadata['name']); // 'John Doe'
print(meta?.connectionDuration); // Duration
```

### Custom Send Function

```dart
// Store sessions by peer ID
final Map<String, Session> peerSessions = {};

await manager.relaySignal(
  roomId: 'room-123',
  signal: signal,
  sendFunction: (peerId, msg) {
    peerSessions[peerId]?.sendMessage(msg);
  },
);
```

### Multiple Managers

You can create separate manager instances for different purposes:

```dart
final mainRoomsManager = WebRTCSignalingManager();
final testRoomsManager = WebRTCSignalingManager();

// Use accordingly
await mainRoomsManager.joinRoom(...);
await testRoomsManager.joinRoom(...);
```

## Complete Example Endpoint

See `serverpod_example.dart` in this directory for a complete working example.

## Testing

### With wscat

```bash
# Install wscat
npm install -g wscat

# Connect
wscat -c ws://localhost:8080/webrtc

# Send join
{"action":"join","roomId":"test","sessionId":"user1"}

# Receive peers
{"type":"peers_list","peers":[],"roomId":"test","sessionId":"user1"}

# Send offer
{"type":"webrtc_offer","payload":"{\"sdp\":\"...\",\"targetPeerId\":\"user2\"}","senderSessionId":"user1"}
```

## Best Practices

1. **Validate SessionIds** — Ensure unique IDs to prevent conflicts
2. **Handle Disconnects** — Call `leavePeer()` when WebSocket closes
3. **Timeout Management** — Remove inactive sessions periodically
4. **Logging** — Add logging for debugging connection issues
5. **Security** — Validate room access, authenticate users
6. **Load Balancing** — For multiple servers, share manager state via Redis/Database

## Troubleshooting

### Signals not relayed

- Check that `sendFunction` correctly sends to peers
- Verify `roomId` and `sessionId` match on both ends
- Ensure WebSocket connections are open

### Peers not showing up

- Confirm `notifyPeerJoined` is called after `joinRoom`
- Check that `sendPeersList` is sending to the correct session
- Verify room exists before relaying

### Memory leaks

- Always call `leavePeer()` when clients disconnect
- Periodically clean up empty rooms with `clearRoom()`
- Monitor `getTotalSessions()` for unexpected growth

## License

MIT - See LICENSE file
