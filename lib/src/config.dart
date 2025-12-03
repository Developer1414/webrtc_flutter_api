/// Configuration presets and builders for WebRTC setup.
/// Provides sensible defaults and easy customization.

class WebRTCConfig {
  /// ICE server configuration (STUN/TURN servers)
  final Map<String, dynamic> iceConfiguration;

  /// Media constraints (audio/video quality)
  final Map<String, dynamic> mediaConstraints;

  const WebRTCConfig({
    required this.iceConfiguration,
    required this.mediaConstraints,
  });

  /// Factory for default production configuration
  /// Uses Google's public STUN servers (no TURN)
  factory WebRTCConfig.defaultConfig() {
    return WebRTCConfig(
      iceConfiguration: {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
          {'urls': 'stun:stun2.l.google.com:19302'},
          {'urls': 'stun:stun3.l.google.com:19302'},
          {'urls': 'stun:stun4.l.google.com:19302'},
        ],
      },
      mediaConstraints: {
        'audio': true,
        'video': false,
      },
    );
  }

  /// Factory for audio-only configuration (low bandwidth, high compatibility)
  factory WebRTCConfig.audioOnly() {
    return WebRTCConfig(
      iceConfiguration: WebRTCConfig.defaultConfig().iceConfiguration,
      mediaConstraints: {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false,
      },
    );
  }

  /// Factory for video+audio configuration
  factory WebRTCConfig.audioAndVideo({
    int videoWidth = 640,
    int videoHeight = 480,
    int videoFrameRate = 30,
  }) {
    return WebRTCConfig(
      iceConfiguration: WebRTCConfig.defaultConfig().iceConfiguration,
      mediaConstraints: {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'width': {'ideal': videoWidth},
          'height': {'ideal': videoHeight},
          'frameRate': {'ideal': videoFrameRate},
        },
      },
    );
  }

  /// Factory for custom configuration with TURN server support
  factory WebRTCConfig.withTurnServer({
    required List<String> stunUrls,
    required String turnUrl,
    required String turnUsername,
    required String turnCredential,
    Map<String, dynamic>? mediaConstraints,
  }) {
    return WebRTCConfig(
      iceConfiguration: {
        'iceServers': [
          ...stunUrls.map((url) => {'urls': url}).toList(),
          {
            'urls': turnUrl,
            'username': turnUsername,
            'credential': turnCredential,
          },
        ],
      },
      mediaConstraints: mediaConstraints ??
          {
            'audio': true,
            'video': false,
          },
    );
  }

  /// Copy constructor for custom overrides
  WebRTCConfig copyWith({
    Map<String, dynamic>? iceConfiguration,
    Map<String, dynamic>? mediaConstraints,
  }) {
    return WebRTCConfig(
      iceConfiguration: iceConfiguration ?? this.iceConfiguration,
      mediaConstraints: mediaConstraints ?? this.mediaConstraints,
    );
  }
}
