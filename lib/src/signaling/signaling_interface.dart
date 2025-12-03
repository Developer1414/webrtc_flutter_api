import '../models/webrtc_signal.dart';

/// Интерфейс для реализации сигналинга (может быть Serverpod, Socket.io, WebSocket и т.д.)
abstract class SignalingInterface {
  /// Инициализация сигналинга для конкретной комнаты
  Future<void> initialize(String roomId);

  /// Отправка сигнала на сервер
  Future<void> sendSignal(WebRtcSignal signal);

  /// Получение потока входящих сигналов
  Stream<WebRtcSignal> getSignalStream();

  /// Очистка ресурсов
  Future<void> dispose();
}
