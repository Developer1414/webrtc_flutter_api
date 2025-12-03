/// Convenient control methods for WebRTC operations.
/// Simplifies common tasks like muting, volume, and peer management.

import 'dart:async';
import 'webrtc_controller.dart';

/// WebRTC controls wrapper for easy operation control.
///
/// Usage:
/// ```dart
/// final controls = WebRTCControls(manager.controller);
///
/// // Toggle microphone
/// controls.toggleMicrophone();
///
/// // Mute specific peer audio (if supported)
/// controls.mutePeer('peer-id');
///
/// // Set remote volume
/// await controls.setRemoteVolume(0.5);
///
/// // Leave room
/// await controls.leaveRoom();
/// ```
class WebRTCControls {
  final WebRTCController _controller;

  // Track muted peers
  final Set<String> _mutedPeers = {};

  WebRTCControls(this._controller);

  // ============================================================================
  // Microphone controls
  // ============================================================================

  /// Toggle local microphone on/off
  void toggleMicrophone() {
    _controller.toggleMute(!_controller.isLocalMuted);
  }

  /// Mute local microphone
  void muteMicrophone() {
    if (!_controller.isLocalMuted) {
      _controller.toggleMute(true);
    }
  }

  /// Unmute local microphone
  void unmuteMicrophone() {
    if (_controller.isLocalMuted) {
      _controller.toggleMute(false);
    }
  }

  /// Check if microphone is muted
  bool get isMicrophoneMuted => _controller.isLocalMuted;

  // ============================================================================
  // Volume controls
  // ============================================================================

  /// Set remote volume (0.0 to 1.0)
  Future<void> setRemoteVolume(double volume) async {
    await _controller.setRemoteVolume(volume);
  }

  /// Get current remote volume
  double get remoteVolume => _controller.remoteVolume;

  /// Increase remote volume by 10%
  Future<void> increaseVolume() async {
    final newVolume = (_controller.remoteVolume + 0.1).clamp(0.0, 1.0);
    await _controller.setRemoteVolume(newVolume);
  }

  /// Decrease remote volume by 10%
  Future<void> decreaseVolume() async {
    final newVolume = (_controller.remoteVolume - 0.1).clamp(0.0, 1.0);
    await _controller.setRemoteVolume(newVolume);
  }

  // ============================================================================
  // Peer management
  // ============================================================================

  /// Toggle mute for a specific peer (visual/UI tracking only)
  /// Note: Actual audio muting is platform-specific via RTCRtpReceiver
  void togglePeerMute(String peerId) {
    if (_mutedPeers.contains(peerId)) {
      _mutedPeers.remove(peerId);
    } else {
      _mutedPeers.add(peerId);
    }
  }

  /// Check if a peer is muted
  bool isPeerMuted(String peerId) => _mutedPeers.contains(peerId);

  /// Mute a specific peer
  void mutePeer(String peerId) {
    _mutedPeers.add(peerId);
  }

  /// Unmute a specific peer
  void unmutePeer(String peerId) {
    _mutedPeers.remove(peerId);
  }

  /// Disconnect from a specific peer
  Future<void> disconnectPeer(String peerId) async {
    await _controller.cleanUpPeer(peerId);
  }

  /// Get list of connected peers
  List<String> get connectedPeers => _controller.connectedPeers;

  /// Get list of currently muted peers
  List<String> get mutedPeers => _mutedPeers.toList();

  // ============================================================================
  // Room management
  // ============================================================================

  /// Leave the room and disconnect from all peers
  Future<void> leaveRoom() async {
    await _controller.leaveRoom();
  }

  /// Get connection state
  dynamic get connectionState => _controller.callState;

  /// Check if connected
  bool get isConnected =>
      _controller.callState.toString() == 'CallConnectionState.connected';
}
