import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Данные одного P2P WebRTC соединения
class PeerConnectionData {
  /// Само RTCPeerConnection
  final RTCPeerConnection peerConnection;

  /// Рендерер для отображения удаленного видео/аудио
  final RTCVideoRenderer renderer;

  /// Уникальный идентификатор пира (обычно sessionId)
  final String peerId;

  /// Инициировали ли мы это соединение (true = мы создали offer)
  final bool isOfferer;

  PeerConnectionData({
    required this.peerConnection,
    required this.renderer,
    required this.peerId,
    required this.isOfferer,
  });
}
