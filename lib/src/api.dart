import 'webrtc_controller.dart';
import 'signaling/signaling_interface.dart';

/// Small helper API to reduce boilerplate for creating and initializing
/// a `WebRTCController`.
class SimpleWebRTC {
  /// Creates and initializes a `WebRTCController` for the given `roomId`.
  ///
  /// Usage:
  /// final controller = await SimpleWebRTC.createController(
  ///   signaling: mySignalingImpl,
  ///   localSessionId: 'session-123',
  ///   roomId: 'room-1',
  /// );
  static Future<WebRTCController> createController({
    required SignalingInterface signaling,
    required String localSessionId,
    required String roomId,
    Map<String, dynamic>? iceConfiguration,
  }) async {
    final controller = WebRTCController(
      signalingInterface: signaling,
      localSessionId: localSessionId,
      iceConfiguration: iceConfiguration,
    );

    await controller.initialize(roomId);
    return controller;
  }
}
