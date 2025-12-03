# WebRTC Flutter API

A comprehensive, production-ready Dart/Flutter WebRTC library for building multi-peer audio/video communication applications.

## Features

✨ **Mesh Topology** - One RTCPeerConnection per peer for optimal scalability  
🎛️ **Easy API** - Simple, well-documented interface  
🔌 **Pluggable Signaling** - Implement any signaling backend (Serverpod, Socket.io, WebSocket, etc.)  
📱 **Cross-Platform** - Works on Flutter Web, iOS, Android, macOS, Windows, and Linux  
🎙️ **Audio/Video Ready** - Built for both audio and video streams  
🔄 **State Management** - Built-in ChangeNotifier for Flutter integration  
📚 **Well-Organized** - Clean separation of concerns with models, controllers, and interfaces  

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  webrtc_flutter_api:
    git:
      url: https://github.com/yourusername/webrtc_flutter_api.git
      ref: main
```

Or for local development:

```yaml
dependencies:
  webrtc_flutter_api:
    path: ../webrtc_flutter_api
```

## Quick Start

### Zero-Config (5 Lines!)

Get started immediately with sensible defaults:

```dart
import 'package:webrtc_flutter_api/webrtc_flutter_api.dart';

final manager = await WebRTCManager.create(
  signaling: MySignalingImplementation(),
  localSessionId: 'user-123',
  roomId: 'room-456',
);

// Use manager.controller in your UI (ChangeNotifier)
// Use manager.connectedPeers, manager.getRemoteRenderer(peerId), etc.
```

That's it! Everything is ready—no extra configuration needed.

---

### Custom Configuration

Want to customize ICE servers, video quality, or media constraints?

```dart
final config = WebRTCConfig.audioAndVideo(
  videoWidth: 1280,
  videoHeight: 720,
  videoFrameRate: 30,
);

final manager = await WebRTCManager.create(
  signaling: MySignalingImplementation(),
  localSessionId: 'user-123',
  roomId: 'room-456',
  config: config,
);
```

**Pre-built Configs:**
- `WebRTCConfig.defaultConfig()` — Audio only (public STUN servers)
- `WebRTCConfig.audioOnly()` — Audio with echo/noise cancellation
- `WebRTCConfig.audioAndVideo()` — Configurable video + audio
- `WebRTCConfig.withTurnServer()` — Custom STUN/TURN servers

---

## Deep Dive: Custom Implementation

### 1. Implement SignalingInterface

First, implement the `SignalingInterface` for your backend:

```dart
import 'package:webrtc_flutter_api/webrtc_flutter_api.dart';

class MySignalingImplementation implements SignalingInterface {
  late StreamController<WebRtcSignal> _signalController;
  
  @override
  Future<void> initialize(String roomId) async {
    _signalController = StreamController<WebRtcSignal>.broadcast();
    // Connect to your signaling backend
    // Example: Serverpod, Socket.io, WebSocket, etc.
  }

  @override
  Future<void> sendSignal(WebRtcSignal signal) async {
    // Send signal to your backend
    // Backend will relay it to other peers
  }

  @override
  Stream<WebRtcSignal> getSignalStream() {
    return _signalController.stream;
  }

  @override
  Future<void> dispose() async {
    await _signalController.close();
  }
}
```

### 2. Use WebRTCManager (Recommended)

```dart
import 'package:provider/provider.dart';
import 'package:webrtc_flutter_api/webrtc_flutter_api.dart';

@override
void initState() {
  super.initState();
  _initializeWebRTC();
}

Future<void> _initializeWebRTC() async {
  final manager = await WebRTCManager.create(
    signaling: MySignalingImplementation(),
    localSessionId: 'user-123',
    roomId: 'room-456',
  );
  
  // Now use manager.controller with Provider
  if (mounted) {
    context.read<WebRTCManager>().controller; // or access manager directly
  }
}
```

Or use with Provider from the start:

```dart
void main() {
  runApp(
    MultiProvider(
      providers: [
        FutureProvider(
          create: (_) => WebRTCManager.create(
            signaling: MySignalingImplementation(),
            localSessionId: 'user-123',
            roomId: 'room-456',
          ),
          initialData: null,
        ),
      ],
      child: const MyApp(),
    ),
  );
}
```

### 3. Old Way: Direct Controller (Still Supported!)

If you prefer raw control, use `WebRTCController` directly:

```dart
import 'package:provider/provider.dart';
import 'package:webrtc_flutter_api/webrtc_flutter_api.dart';

void main() {
  final signalingImpl = MySignalingImplementation();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => WebRTCController(
        signalingInterface: signalingImpl,
        localSessionId: 'unique-session-id', // e.g., UUID
      ),
      child: const MyApp(),
    ),
  );
}
```

### 3. Easy Events, Controls & UI (One-Liners)

Everything is ready with built-in convenience methods and pre-made widgets:

```dart
// 🎧 Event Listening (no boilerplate)
manager.events.onPeersChanged.listen((peers) {
  print('Peers changed: $peers');
});

manager.events.onConnectionStateChanged.listen((state) {
  print('Connection: $state');
});

manager.events.onMuteStateChanged.listen((isMuted) {
  print('Muted: $isMuted');
});

// 🎙️ Easy Controls
manager.controls.toggleMicrophone();
manager.controls.muteMicrophone();
manager.controls.unmuteMicrophone();
await manager.controls.setRemoteVolume(0.5);
await manager.controls.increaseVolume();
await manager.controls.decreaseVolume();

// 👥 Peer Management
manager.controls.mutePeer('peer-id');
manager.controls.unmutePeer('peer-id');
await manager.controls.disconnectPeer('peer-id');

// 📱 Ready-to-use UI Widgets (ONE LINE!)
WebRTCPeerGridView(controller: manager.controller)

WebRTCConnectionStatus(controller: manager.controller)

WebRTCControlPanel(
  controller: manager.controller,
  onLeavePressed: () => Navigator.pop(context),
  showVolumeSlider: true,
)
```

---

### 4. Complete Example: No Boilerplate

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Voice Call')),
    body: ChangeNotifierProvider<WebRTCController>.value(
      value: manager.controller,
      child: Column(
        children: [
          // Status bar (1 line)
          WebRTCConnectionStatus(controller: manager.controller),
          
          // Peers grid (1 line)
          Expanded(
            child: WebRTCPeerGridView(controller: manager.controller),
          ),
          
          // Controls (1 line)
          WebRTCControlPanel(
            controller: manager.controller,
            onLeavePressed: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
```

That's it! No custom widgets, no boilerplate, everything works!

---

### 5. Customization: Override Defaults

```dart
// Custom peer card layout
WebRTCPeerGridView(
  controller: manager.controller,
  crossAxisCount: 3,
  peerBuilder: (context, peerId, renderer) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue, width: 3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          renderer != null
              ? RTCVideoView(renderer)
              : const Center(child: Icon(Icons.person)),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(peerId, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  },
)

// Custom status colors
WebRTCConnectionStatus(
  controller: manager.controller,
  connectedColor: Colors.blue,
  connectingColor: Colors.purple,
  failedColor: Colors.orange,
)

// Custom control panel
WebRTCControlPanel(
  controller: manager.controller,
  muteColor: Colors.purple,
  leaveColor: Colors.redAccent,
  showVolumeSlider: false,
)
```

---

## Architecture

### Models

- **`CallConnectionState`** - Enum for connection states (disconnected, connecting, connected, failed)
- **`PeerConnectionData`** - Holds RTCPeerConnection, renderer, peerId, and isOfferer flag
- **`WebRtcSignal`** - Signal object with type, payload, and sender info

### Core

- **`WebRTCController`** - Main controller extending ChangeNotifier
  - Manages peer connections (mesh topology)
  - Handles signaling logic (offer/answer/ICE)
  - Provides UI integration via Provider pattern
  - Handles media stream setup and cleanup

- **`WebRTCManager`** - Convenience wrapper with sensible defaults
  - One-line initialization: `WebRTCManager.create(...)`
  - Built-in config presets
  - Simplified API for common operations

### Events & Controls

- **`WebRTCEvents`** - Easy event streams
  - `onPeersChanged` — Listen to peer list changes
  - `onConnectionStateChanged` — Listen to connection state
  - `onMuteStateChanged` — Listen to mute state changes

- **`WebRTCControls`** - Simple operation control
  - Microphone: `toggleMicrophone()`, `muteMicrophone()`, `unmuteMicrophone()`
  - Volume: `setRemoteVolume()`, `increaseVolume()`, `decreaseVolume()`
  - Peers: `mutePeer()`, `unmutePeer()`, `disconnectPeer()`
  - Room: `leaveRoom()`

### Widgets

- **`WebRTCPeerGridView`** - Ready-to-use peer grid (customize with `peerBuilder`)
- **`WebRTCConnectionStatus`** - Status indicator with customizable colors
- **`WebRTCControlPanel`** - Mute button, volume slider, leave button
- **`WebRTCEmptyPeersPlaceholder`** - Placeholder when no peers connected

- **`WebRTCConfig`** - Configuration builder with factory methods
  - `defaultConfig()` — Production defaults
  - `audioOnly()` — Audio + noise cancellation
  - `audioAndVideo()` — Customizable video quality
  - `withTurnServer()` — Custom STUN/TURN setup

### Signaling

- **`SignalingInterface`** - Abstract interface for implementing custom signaling backends

## Advanced Usage

### Custom Config Example

```dart
final config = WebRTCConfig.withTurnServer(
  stunUrls: [
    'stun:stun.l.google.com:19302',
    'stun:stun1.l.google.com:19302',
  ],
  turnUrl: 'turn:turn.example.com',
  turnUsername: 'user',
  turnCredential: 'pass',
  mediaConstraints: {
    'audio': {'echoCancellation': true},
    'video': {
      'width': {'ideal': 1920},
      'height': {'ideal': 1080},
      'frameRate': {'ideal': 60},
    },
  },
);

final manager = await WebRTCManager.create(
  signaling: MySignalingImplementation(),
  localSessionId: 'user-123',
  roomId: 'room-456',
  config: config,
);
```

### Direct Controller Usage

```dart

## Server Integration Guide

### Signaling Flow Overview

The WebRTC API handles peer-to-peer connections. Your server's role is to **relay signaling messages** (offers, answers, ICE candidates) between clients. Here's the flow:

```
Client A ─────→ Server ─────→ Client B
  (offer)       (relay)       (receives)
         ←─────────────────
         (answer back)
```

### Implementing SignalingInterface on Flutter Side

Your Flutter app needs a `SignalingInterface` implementation to communicate with your server:

```dart
class MyServerSignaling implements SignalingInterface {
  final String serverUrl; // e.g., "wss://your-server.com"
  late WebSocket _webSocket;
  late StreamController<WebRtcSignal> _signalController;
  String? _roomId;

  MyServerSignaling({required this.serverUrl});

  @override
  Future<void> initialize(String roomId) async {
    _roomId = roomId;
    _signalController = StreamController<WebRtcSignal>.broadcast();
    
    // Connect to your server
    _webSocket = await WebSocket.connect('$serverUrl/webrtc');
    
    // Join room
    _webSocket.add(jsonEncode({
      'action': 'join',
      'roomId': roomId,
      'sessionId': 'unique-client-id', // Same as localSessionId
    }));

    // Listen for incoming signals
    _webSocket.listen(
      (message) {
        final data = jsonDecode(message);
        final signal = WebRtcSignal.fromJson(data);
        _signalController.add(signal);
      },
      onError: (error) => _signalController.addError(error),
      onDone: () => _signalController.close(),
    );
  }

  @override
  Future<void> sendSignal(WebRtcSignal signal) async {
    _webSocket.add(jsonEncode(signal.toJson()));
  }

  @override
  Stream<WebRtcSignal> getSignalStream() {
    return _signalController.stream;
  }

  @override
  Future<void> dispose() async {
    await _webSocket.close();
    await _signalController.close();
  }
}

// Usage
final manager = await WebRTCManager.create(
  signaling: MyServerSignaling(serverUrl: 'wss://my-server.com'),
  localSessionId: 'user-${DateTime.now().millisecondsSinceEpoch}',
  roomId: 'room-123',
);
```

### Server-Side Implementation (Node.js / Express + WebSocket)

Here's a minimal server implementation in **Node.js** to handle signaling:

```javascript
const express = require('express');
const expressWs = require('express-ws');
const app = express();
expressWs(app);

// Store active rooms and their clients
const rooms = new Map();

app.ws('/webrtc', (ws, req) => {
  let clientSessionId = null;
  let roomId = null;

  ws.on('message', (msg) => {
    try {
      const data = JSON.parse(msg);
      
      // Handle join room
      if (data.action === 'join') {
        roomId = data.roomId;
        clientSessionId = data.sessionId;

        // Create room if doesn't exist
        if (!rooms.has(roomId)) {
          rooms.set(roomId, new Map());
        }

        // Add client to room
        const room = rooms.get(roomId);
        room.set(clientSessionId, ws);

        // Send current participants to new client
        const participants = Array.from(room.keys()).filter(id => id !== clientSessionId);
        ws.send(JSON.stringify({
          action: 'peers',
          peers: participants,
        }));

        // Notify others about new participant
        room.forEach((otherWs, otherId) => {
          if (otherId !== clientSessionId) {
            otherWs.send(JSON.stringify({
              type: 'peer_joined',
              peerId: clientSessionId,
            }));
          }
        });

        console.log(`Client ${clientSessionId} joined room ${roomId}`);
        return;
      }

      // Handle signaling messages (offer, answer, ICE candidates)
      if (data.type && ['webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate'].includes(data.type)) {
        const room = rooms.get(roomId);
        if (!room) return;

        // Extract target peer from payload
        const payload = JSON.parse(data.payload);
        const targetPeerId = payload.targetPeerId;

        if (targetPeerId && room.has(targetPeerId)) {
          const targetWs = room.get(targetPeerId);
          // Forward signal to target peer
          targetWs.send(JSON.stringify(data));
          console.log(`Forwarded ${data.type} from ${clientSessionId} to ${targetPeerId}`);
        }
        return;
      }

      // Handle peer disconnection
      if (data.type === 'leave_room') {
        handleClientDisconnect();
        return;
      }
    } catch (err) {
      console.error('Error processing message:', err);
    }
  });

  ws.on('close', () => {
    handleClientDisconnect();
  });

  function handleClientDisconnect() {
    if (roomId && clientSessionId) {
      const room = rooms.get(roomId);
      if (room) {
        room.delete(clientSessionId);
        
        // Notify others about disconnection
        room.forEach((otherWs) => {
          otherWs.send(JSON.stringify({
            type: 'peer_left',
            peerId: clientSessionId,
          }));
        });

        // Clean up empty rooms
        if (room.size === 0) {
          rooms.delete(roomId);
        }
      }
      console.log(`Client ${clientSessionId} left room ${roomId}`);
    }
  }
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(3000, () => {
  console.log('WebRTC signaling server running on port 3000');
});
```

### Server-Side Implementation (Serverpod - Dart)

If you prefer Dart/Serverpod backend:

```dart
// server/lib/src/endpoints/webrtc.dart
import 'package:serverpod/serverpod.dart';
import 'dart:convert';

// Store active rooms
final Map<String, Map<String, WebsocketSession>> _rooms = {};

Future<void> handleWebRTCStream(
  Session session,
  String message,
) async {
  try {
    final data = jsonDecode(message);
    
    // Handle join room
    if (data['action'] == 'join') {
      final roomId = data['roomId'] as String;
      final sessionId = data['sessionId'] as String;

      _rooms.putIfAbsent(roomId, () => {});
      _rooms[roomId]![sessionId] = session.websocket;

      // Send current participants
      final participants = _rooms[roomId]!.keys
          .where((id) => id != sessionId)
          .toList();
      
      session.websocket.send(jsonEncode({
        'action': 'peers',
        'peers': participants,
      }));

      // Notify others
      for (final otherId in _rooms[roomId]!.keys) {
        if (otherId != sessionId) {
          _rooms[roomId]![otherId].send(jsonEncode({
            'type': 'peer_joined',
            'peerId': sessionId,
          }));
        }
      }

      return;
    }

    // Handle signaling (offer, answer, ICE)
    if (['webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate']
        .contains(data['type'])) {
      final roomId = _getRoomForSession(session);
      if (roomId == null) return;

      final payload = jsonDecode(data['payload'] as String);
      final targetPeerId = payload['targetPeerId'];

      if (targetPeerId != null && _rooms[roomId]?.containsKey(targetPeerId) ?? false) {
        _rooms[roomId]![targetPeerId].send(message);
      }
      return;
    }
  } catch (e) {
    print('Error in WebRTC handler: $e');
  }
}

String? _getRoomForSession(Session session) {
  for (final (roomId, peers) in _rooms.entries) {
    if (peers.containsValue(session.websocket)) {
      return roomId;
    }
  }
  return null;
}
```

### Key Signaling Protocol

Your server should handle these message types:

| Type | From | To | Purpose |
|------|------|----|----|
| `join` | Client | Server | Join a room (includes roomId, sessionId) |
| `webrtc_offer` | Client A | Server → Client B | SDP offer to establish connection |
| `webrtc_answer` | Client B | Server → Client A | SDP answer to accept connection |
| `webrtc_ice_candidate` | Any Client | Server → Target Peer | ICE candidate for NAT traversal |
| `leave_room` | Client | Server | Client is leaving (notify others) |
| `peer_joined` | Server | All Clients | New peer joined (server notifies) |
| `peer_left` | Server | All Clients | Peer disconnected (server notifies) |

### Server Responsibilities

✅ **Must do:**
- Store active clients per room
- Forward WebRTC signals (offer/answer/ICE) between clients
- Notify all clients when someone joins/leaves
- Close connections cleanly

❌ **Should NOT do:**
- Process or modify WebRTC payloads
- Handle audio/video directly (that's peer-to-peer)
- Store call history (do it separately)

### Testing Your Signaling

Use `curl` or Postman to test WebSocket:

```bash
# Using wscat (npm install -g wscat)
wscat -c ws://localhost:3000/webrtc

# Send join message
{"action":"join","roomId":"test-room","sessionId":"user-1"}

# Simulate offer
{"type":"webrtc_offer","payload":"{\"sdp\":\"...\",\"type\":\"offer\",\"targetPeerId\":\"user-2\"}","senderSessionId":"user-1"}
```

---

## Mesh vs SFU Topology

This library implements **Mesh Topology**:
- Each peer creates a direct WebRTC connection to every other peer
- Works well for small groups (2-6 participants)
- Lower latency
- Higher bandwidth usage (scales O(n²))

For larger groups, consider using **SFU** (Selective Forwarding Unit) like Janus or Mediasoup instead.

## Dependencies

- `flutter_webrtc: ^0.9.43` - Core WebRTC functionality
- `provider: ^6.0.0` - State management

## Platform Support

- ✅ Flutter Web (Chrome, Firefox, Safari, Edge)
- ✅ iOS (13+)
- ✅ Android (API 21+)
- ✅ macOS (10.14+)
- ✅ Windows (10+)
- ✅ Linux (with appropriate libs)

## Example Project

For a complete example using Serverpod signaling, see the Voxly project in this repository:
- `voxly_flutter` - Flutter Web client
- `voxly_server` - Serverpod backend with signaling

## Troubleshooting

### No audio/video

- Ensure you requested permissions on the platform level
- Check ICE connectivity with your STUN/TURN servers
- Verify your signaling backend is delivering messages correctly

### Peer connection fails

- Check that sessionIds are unique across clients
- Ensure ICE candidates are being sent properly
- Verify that offer/answer SDP is being transmitted

### Memory leaks

- Always call `controller.leaveRoom()` when done
- Call `controller.dispose()` in your widget's dispose method
- Ensure all subscriptions to signal stream are cancelled

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details

## Support

For issues, questions, or suggestions, please open an issue on GitHub.

---

Built with ❤️ for the Flutter community
