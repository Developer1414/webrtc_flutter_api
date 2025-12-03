/// Состояние WebRTC соединения
enum CallConnectionState {
  /// Нет активного соединения
  disconnected,

  /// Процесс установления соединения
  connecting,

  /// Соединение установлено
  connected,

  /// Ошибка соединения
  failed,
}
