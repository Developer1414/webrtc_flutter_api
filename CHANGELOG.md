# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-12-03

### Added
- Initial release of WebRTC Flutter API
- Complete mesh topology WebRTC implementation
- `WebRTCController` with full P2P management
- `SignalingInterface` for pluggable signaling backends
- Models: `CallConnectionState`, `PeerConnectionData`, `WebRtcSignal`
- Support for offer/answer/ICE candidate exchange
- Automatic media stream setup and cleanup
- Mute/unmute functionality
- Volume control support
- Comprehensive documentation and examples
- Built-in ChangeNotifier for Flutter state management

### Features
- Mesh topology (one RTCPeerConnection per peer)
- Cross-platform support (Web, iOS, Android, macOS, Windows, Linux)
- Clean, well-organized API
- Provider integration for Flutter
- Proper resource cleanup and lifecycle management

[1.0.0]: https://github.com/yourusername/webrtc_flutter_api/releases/tag/v1.0.0
