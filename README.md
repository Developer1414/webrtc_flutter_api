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

### 3. Use in UI (Any Approach)

All approaches use the same UI code with `ChangeNotifier`:

```dart
Consumer<WebRTCController>(
  builder: (context, controller, _) {
    return Column(
      children: [
        // Display connected peers
        Wrap(
          children: controller.connectedPeers.map((peerId) {
            final renderer = controller.getRemoteRenderer(peerId);
            return renderer != null
                ? SizedBox(
                    width: 120,
                    height: 120,
                    child: RTCVideoView(renderer),
                  )
                : Container(
                    width: 120,
                    height: 120,
                    color: Colors.grey,
                    child: Icon(Icons.person),
                  );
          }).toList(),
        ),
        
        // Mute button
        FloatingActionButton(
          onPressed: () => controller.toggleMute(!controller.isLocalMuted),
          child: Icon(controller.isLocalMuted ? Icons.mic_off : Icons.mic),
        ),
        
        // Volume slider
        Slider(
          value: controller.remoteVolume,
          onChanged: (v) => controller.setRemoteVolume(v),
        ),
      ],
    );
  },
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
