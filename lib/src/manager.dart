/// Ultra-simple WebRTC manager for zero-config or custom integration.
/// One line to initialize, everything else handled automatically.

import 'dart:async';
import 'webrtc_controller.dart';
import 'signaling/signaling_interface.dart';
import 'config.dart';
import 'events.dart';
import 'controls.dart';

/// Simplified WebRTC manager with sensible defaults.
///
/// **Zero-Config Usage:**
/// ```dart
/// final manager = await WebRTCManager.create(
///   signaling: mySignalingImpl,
///   localSessionId: 'user-123',
///   roomId: 'room-456',
/// );
///
/// // That's it! Use manager.controller in your UI
/// ```
///
/// **Custom Configuration:**
/// ```dart
/// final config = WebRTCConfig.audioAndVideo(videoWidth: 1280, videoHeight: 720);
/// final manager = await WebRTCManager.create(
///   signaling: mySignalingImpl,
///   localSessionId: 'user-123',
///   roomId: 'room-456',
///   config: config,
/// );
/// ```
class WebRTCManager {
  /// The underlying WebRTC controller
  final WebRTCController controller;

  /// Configuration used for this session
  final WebRTCConfig config;

  /// Room ID this manager is connected to
  final String roomId;

  /// Easy event listening
  late final WebRTCEvents events;

  /// Easy control methods
  late final WebRTCControls controls;

  WebRTCManager({
    required this.controller,
    required this.config,
    required this.roomId,
  }) {
    events = WebRTCEvents(controller);
    controls = WebRTCControls(controller);
  }

  /// Creates and initializes a WebRTC manager in one call.
  ///
  /// Parameters:
  /// - `signaling`: Your signaling implementation
  /// - `localSessionId`: Unique ID for this client (e.g., UUID, user ID)
  /// - `roomId`: Room to join
  /// - `config`: (Optional) WebRTCConfig. Uses defaultConfig() if not provided.
  static Future<WebRTCManager> create({
    required SignalingInterface signaling,
    required String localSessionId,
    required String roomId,
    WebRTCConfig? config,
  }) async {
    final finalConfig = config ?? WebRTCConfig.defaultConfig();

    final webrtcController = WebRTCController(
      signalingInterface: signaling,
      localSessionId: localSessionId,
      iceConfiguration: finalConfig.iceConfiguration,
    );

    await webrtcController.initialize(roomId);

    return WebRTCManager(
      controller: webrtcController,
      config: finalConfig,
      roomId: roomId,
    );
  }

  /// Convenience method: get list of connected peer IDs
  List<String> get connectedPeers => controller.connectedPeers;

  /// Convenience method: get remote renderer for a peer
  dynamic getRemoteRenderer(String peerId) {
    return controller.getRemoteRenderer(peerId);
  }

  /// Convenience method: toggle local audio mute
  void toggleAudio(bool isMuted) {
    controller.toggleMute(isMuted);
  }

  /// Convenience method: set remote volume
  Future<void> setVolume(double volume) async {
    await controller.setRemoteVolume(volume);
  }

  /// Convenience method: get current connection state
  dynamic get connectionState => controller.callState;

  /// Convenience method: check if local audio is muted
  bool get isAudioMuted => controller.isLocalMuted;

  /// Leave room and clean up all resources
  Future<void> dispose() async {
    events.dispose();
    await controller.leaveRoom();
  }
}
