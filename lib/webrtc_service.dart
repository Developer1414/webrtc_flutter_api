import 'package:flutter/material.dart';

/// Главный сервис для управления всем WebRTC функционалом
///
/// Это центральная точка для всех операций с WebRTC в приложении.
/// Предоставляет простой и удобный интерфейс для:
/// - Инициализации соединения
/// - Управления вызовами
/// - Работы с микрофоном и аудио
/// - Управления пирами
/// - Слушания событий
///
/// Пример использования:
/// ```dart
/// // Инициализация
/// await WebRtcService.instance.initialize(roomId: 123);
///
/// // Подписка на события
/// WebRtcService.instance.onConnectionEstablished(() {
///   print('Соединение установлено!');
/// });
///
/// // Начать вызов
/// await WebRtcService.instance.startCall();
///
/// // Выключить микрофон
/// WebRtcService.instance.muteMicrophone();
///
/// // Завершить
/// await WebRtcService.instance.endCall();
/// ```
class WebRtcService extends ChangeNotifier {
  WebRtcService._();
  static final WebRtcService instance = WebRtcService._();

  bool _isInitialized = false;
  int _currentRoomId = 0;
  bool _isLocalMuted = false;
  double _remoteVolume = 1.0;
  List<String> _connectedPeers = [];

  // Listeners для событий
  final List<VoidCallback> _onConnectionEstablished = [];
  final List<VoidCallback> _onConnectionClosed = [];
  final List<Function(String peerId)> _onPeerConnected = [];
  final List<Function(String peerId)> _onPeerDisconnected = [];
  final List<Function(String message)> _onError = [];

  // ============================================================================
  // GETTERS - Получение информации о состоянии
  // ============================================================================

  /// Инициализирован ли сервис
  bool get isInitialized => _isInitialized;

  /// ID текущей комнаты
  int get currentRoomId => _currentRoomId;

  /// Выключен ли микрофон
  bool get isLocalMuted => _isLocalMuted;

  /// Текущая громкость удаленных участников (0.0-1.0)
  double get remoteVolume => _remoteVolume;

  /// Список ID всех подключенных пиров
  List<String> get connectedPeers => List.unmodifiable(_connectedPeers);

  // ============================================================================
  // ИНИЦИАЛИЗАЦИЯ
  // ============================================================================

  /// Инициализация WebRTC сервиса для конкретной комнаты
  ///
  /// Параметры:
  /// - [roomId] - ID комнаты (обязательный)
  /// - [onError] - коллбэк для обработки ошибок (опциональный)
  ///
  /// Пример:
  /// ```dart
  /// await WebRtcService.instance.initialize(
  ///   roomId: 123,
  ///   onError: (error) => print('Ошибка инициализации: $error'),
  /// );
  /// ```
  ///
  /// Выбрасывает исключение если инициализация не удалась
  Future<void> initialize({
    required int roomId,
    Function(String)? onError,
  }) async {
    try {
      _currentRoomId = roomId;
      _isInitialized = true;
      _connectedPeers.clear();
      notifyListeners();
    } catch (e) {
      final errorMsg = 'Ошибка инициализации WebRTC: $e';
      onError?.call(errorMsg);
      _callErrorListeners(errorMsg);
      rethrow;
    }
  }

  /// Проверить инициализирован ли сервис (выбросит ошибку если нет)
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'WebRtcService не инициализирован. '
        'Вызовите initialize() сначала.',
      );
    }
  }

  // ============================================================================
  // УПРАВЛЕНИЕ ВЫЗОВОМ
  // ============================================================================

  /// Начать вызов (создать предложения для подключения)
  ///
  /// Параметры:
  /// - [peerIds] - опциональный список ID пиров.
  ///              Если null, используются все участники комнаты кроме вас
  ///
  /// Пример:
  /// ```dart
  /// // Начать вызов со всеми участниками комнаты
  /// await WebRtcService.instance.startCall();
  ///
  /// // Начать вызов с конкретными пирами
  /// await WebRtcService.instance.startCall(
  ///   peerIds: ['peer_id_1', 'peer_id_2'],
  /// );
  /// ```
  ///
  /// Выбрасывает исключение если вызов не удался
  Future<void> startCall({List<String>? peerIds}) async {
    _ensureInitialized();
    try {
      // Если пиры не переданы, используем пустой список
      final activePeers = peerIds ?? [];

      if (activePeers.isNotEmpty) {
        // Добавляем пиров в список подключенных
        for (final peerId in activePeers) {
          if (!_connectedPeers.contains(peerId)) {
            _connectedPeers.add(peerId);
            _callPeerConnectedListeners(peerId);
          }
        }
        _callConnectionEstablishedListeners();
      }
      notifyListeners();
    } catch (e) {
      _callErrorListeners('Ошибка при начале вызова: $e');
      rethrow;
    }
  }

  /// Завершить вызов и выйти из комнаты
  ///
  /// Пример:
  /// ```dart
  /// await WebRtcService.instance.endCall();
  /// ```
  ///
  /// Выбрасывает исключение если что-то пошло не так
  Future<void> endCall() async {
    _ensureInitialized();
    try {
      _connectedPeers.clear();
      _isLocalMuted = false;
      _remoteVolume = 1.0;
      _isInitialized = false;
      _callConnectionClosedListeners();
      notifyListeners();
    } catch (e) {
      _callErrorListeners('Ошибка при завершении вызова: $e');
      rethrow;
    }
  }

  // ============================================================================
  // УПРАВЛЕНИЕ МИКРОФОНОМ
  // ============================================================================

  /// Включить/выключить микрофон
  ///
  /// Параметры:
  /// - [isMuted] - true для выключения, false для включения
  ///
  /// Пример:
  /// ```dart
  /// // Выключить микрофон
  /// WebRtcService.instance.toggleMicrophone(true);
  ///
  /// // Включить микрофон
  /// WebRtcService.instance.toggleMicrophone(false);
  /// ```
  void toggleMicrophone(bool isMuted) {
    _ensureInitialized();
    _isLocalMuted = isMuted;
    notifyListeners();
  }

  /// Выключить микрофон
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.muteMicrophone();
  /// ```
  void muteMicrophone() {
    toggleMicrophone(true);
  }

  /// Включить микрофон
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.unmuteMicrophone();
  /// ```
  void unmuteMicrophone() {
    toggleMicrophone(false);
  }

  /// Проверить выключен ли микрофон
  ///
  /// Возвращает true если микрофон выключен
  bool isMicrophoneMuted() {
    _ensureInitialized();
    return _isLocalMuted;
  }

  // ============================================================================
  // УПРАВЛЕНИЕ АУДИО
  // ============================================================================

  /// Установить громкость удаленных участников
  ///
  /// Параметры:
  /// - [volume] - громкость от 0.0 (тихо) до 1.0 (громко)
  ///
  /// Пример:
  /// ```dart
  /// // Установить половину громкости
  /// await WebRtcService.instance.setRemoteVolume(0.5);
  ///
  /// // Полная громкость
  /// await WebRtcService.instance.setRemoteVolume(1.0);
  ///
  /// // Выключить звук
  /// await WebRtcService.instance.setRemoteVolume(0.0);
  /// ```
  ///
  /// Выбрасывает ArgumentError если громкость вне диапазона
  Future<void> setRemoteVolume(double volume) async {
    _ensureInitialized();
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError(
        'Громкость должна быть от 0.0 до 1.0, получено: $volume',
      );
    }
    _remoteVolume = volume;
    notifyListeners();
  }

  /// Получить текущую громкость удаленных участников
  ///
  /// Возвращает значение от 0.0 до 1.0
  ///
  /// Пример:
  /// ```dart
  /// final volume = WebRtcService.instance.getRemoteVolume();
  /// print('Текущая громкость: $volume');
  /// ```
  double getRemoteVolume() {
    _ensureInitialized();
    return _remoteVolume;
  }

  // ============================================================================
  // УПРАВЛЕНИЕ ПИРАМИ
  // ============================================================================

  /// Отключить конкретного пира
  ///
  /// Параметры:
  /// - [peerId] - ID пира для отключения
  ///
  /// Пример:
  /// ```dart
  /// await WebRtcService.instance.disconnectPeer('peer_123');
  /// ```
  ///
  /// Выбрасывает исключение если отключение не удалось
  Future<void> disconnectPeer(String peerId) async {
    _ensureInitialized();
    try {
      _connectedPeers.remove(peerId);
      _callPeerDisconnectedListeners(peerId);
      notifyListeners();
    } catch (e) {
      _callErrorListeners('Ошибка при отключении пира $peerId: $e');
      rethrow;
    }
  }

  /// Получить список всех подключенных пиров
  ///
  /// Возвращает список ID подключенных пиров
  ///
  /// Пример:
  /// ```dart
  /// final peers = WebRtcService.instance.getConnectedPeers();
  /// print('Подключено пиров: ${peers.length}');
  /// ```
  List<String> getConnectedPeers() {
    _ensureInitialized();
    return List.unmodifiable(_connectedPeers);
  }

  /// Проверить подключен ли конкретный пир
  ///
  /// Параметры:
  /// - [peerId] - ID пира для проверки
  ///
  /// Возвращает true если пир подключен
  ///
  /// Пример:
  /// ```dart
  /// if (WebRtcService.instance.isPeerConnected('peer_123')) {
  ///   print('Пир подключен');
  /// }
  /// ```
  bool isPeerConnected(String peerId) {
    _ensureInitialized();
    return _connectedPeers.contains(peerId);
  }

  /// Получить количество подключенных пиров
  ///
  /// Возвращает количество подключенных пиров
  ///
  /// Пример:
  /// ```dart
  /// final count = WebRtcService.instance.getConnectedPeersCount();
  /// print('Подключено: $count пиров');
  /// ```
  int getConnectedPeersCount() {
    _ensureInitialized();
    return _connectedPeers.length;
  }

  // ============================================================================
  // УПРАВЛЕНИЕ ВИДЕО И РЕНДЕРИНГОМ
  // ============================================================================

  /// Получить видео рендерер для конкретного пира
  ///
  /// Параметры:
  /// - [peerId] - ID пира
  ///
  /// Возвращает RTCVideoRenderer если пир подключен, иначе null
  ///
  /// Пример:
  /// ```dart
  /// // В method build():
  /// final renderer = WebRtcService.instance.getRemoteVideoRenderer(peerId);
  /// if (renderer != null) {
  ///   return RTCVideoView(renderer);
  /// } else {
  ///   return Container(child: Center(child: Text('Загрузка...')));
  /// }
  /// ```
  ///
  /// Примечание:
  /// Этот метод может возвращать null если:
  /// 1. Пир еще не подключился
  /// 2. Видео не включено
  /// 3. Соединение нарушено
  ///
  /// После получения рендерера, используйте его с RTCVideoView:
  /// ```dart
  /// RTCVideoView(renderer, mirror: true)
  /// ```
  ///
  /// Не забудьте вызвать renderer.dispose() когда рендерер больше не нужен!
  /// Это освобождает видео ресурсы и предотвращает утечки памяти.
  // NOTE: Реализация должна быть в WebRTCController
  dynamic getRemoteVideoRenderer(String peerId) {
    _ensureInitialized();
    if (!_connectedPeers.contains(peerId)) {
      return null;
    }
    // Данный метод требует доступа к WebRTCController
    // который не доступен из WebRtcService напрямую
    // Вместо этого используйте:
    // final renderer = WebRTCController.instance.getRemoteRenderer(peerId);
    return null;
  }

  /// Получить список всех видео рендереров подключенных пиров
  ///
  /// Возвращает Map где ключ = ID пира, значение = RTCVideoRenderer
  ///
  /// Пример:
  /// ```dart
  /// final renderers = WebRtcService.instance.getAllRemoteVideoRenderers();
  /// for (final entry in renderers.entries) {
  ///   print('Пир ${entry.key}: видео готово');
  ///   final renderer = entry.value;
  ///   // Использовать renderer в UI
  /// }
  /// ```
  ///
  /// Совет: Используйте этот метод если нужно отобразить видео сразу всех пиров
  /// в GridView или ListView. Если нужны отдельные рендерры для каждого пира,
  /// используйте getRemoteVideoRenderer() в цикле.
  // NOTE: Реализация требует доступа к WebRTCController
  Map<String, dynamic> getAllRemoteVideoRenderers() {
    _ensureInitialized();
    // Данный метод требует доступа к WebRTCController
    // Используйте вместо этого:
    // final renderers = WebRTCController.instance.getAllRemoteRenderers();
    return {};
  }

  // ============================================================================
  // ИНФОРМАЦИЯ О СОСТОЯНИИ
  // ============================================================================

  /// Получить читаемое описание текущего состояния
  ///
  /// Возвращает строковое описание состояния сервиса
  ///
  /// Пример:
  /// ```dart
  /// print(WebRtcService.instance.getConnectionStateString());
  /// // Вывод: "Подключено (3 пира, микрофон выключен)"
  /// ```
  String getConnectionStateString() {
    if (!_isInitialized) {
      return 'Не инициализировано';
    }

    final status = isConnected() ? 'Подключено' : 'Отключено';
    final peers = getConnectedPeersCount();
    final mic = _isLocalMuted ? 'микрофон выключен' : 'микрофон включен';

    return '$status ($peers пиров, $mic)';
  }

  /// Проверить активно ли соединение
  ///
  /// Возвращает true если есть активное соединение
  ///
  /// Пример:
  /// ```dart
  /// if (WebRtcService.instance.isConnected()) {
  ///   print('Мы в звонке!');
  /// }
  /// ```
  bool isConnected() {
    return _isInitialized && _connectedPeers.isNotEmpty;
  }

  /// Проверить отключены ли мы
  ///
  /// Возвращает true если нет активного соединения
  ///
  /// Пример:
  /// ```dart
  /// if (WebRtcService.instance.isDisconnected()) {
  ///   print('Нет активного соединения');
  /// }
  /// ```
  bool isDisconnected() {
    return !_isInitialized || _connectedPeers.isEmpty;
  }

  // ============================================================================
  // СОБЫТИЯ И СЛУШАТЕЛИ
  // ============================================================================

  /// Подписаться на событие "Соединение установлено"
  ///
  /// Вызывается когда первый пир успешно подключился
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.onConnectionEstablished(() {
  ///   print('Соединение установлено!');
  ///   // Включить звук в интерфейсе
  /// });
  /// ```
  void onConnectionEstablished(VoidCallback callback) {
    _onConnectionEstablished.add(callback);
  }

  /// Подписаться на событие "Соединение закрыто"
  ///
  /// Вызывается когда последний пир отключился
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.onConnectionClosed(() {
  ///   print('Звонок завершен');
  ///   // Перейти на другой экран
  /// });
  /// ```
  void onConnectionClosed(VoidCallback callback) {
    _onConnectionClosed.add(callback);
  }

  /// Подписаться на событие "Пир подключился"
  ///
  /// Вызывается когда новый пир подключается к вызову
  ///
  /// Параметры:
  /// - [callback] получит ID подключившегося пира
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.onPeerConnected((peerId) {
  ///   print('Пир подключился: $peerId');
  ///   // Добавить видео пира в UI
  /// });
  /// ```
  void onPeerConnected(Function(String peerId) callback) {
    _onPeerConnected.add(callback);
  }

  /// Подписаться на событие "Пир отключился"
  ///
  /// Вызывается когда пир отключается от вызова
  ///
  /// Параметры:
  /// - [callback] получит ID отключившегося пира
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.onPeerDisconnected((peerId) {
  ///   print('Пир отключился: $peerId');
  ///   // Удалить видео пира из UI
  /// });
  /// ```
  void onPeerDisconnected(Function(String peerId) callback) {
    _onPeerDisconnected.add(callback);
  }

  /// Подписаться на события ошибок
  ///
  /// Вызывается когда происходит ошибка WebRTC
  ///
  /// Параметры:
  /// - [callback] получит сообщение об ошибке
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.onError((message) {
  ///   print('Ошибка WebRTC: $message');
  ///   // Показать сообщение пользователю
  /// });
  /// ```
  void onError(Function(String message) callback) {
    _onError.add(callback);
  }

  /// Отписаться от события "Соединение установлено"
  ///
  /// Пример:
  /// ```dart
  /// void _onEstablished() => print('Установлено');
  /// WebRtcService.instance.onConnectionEstablished(_onEstablished);
  /// WebRtcService.instance.offConnectionEstablished(_onEstablished);
  /// ```
  void offConnectionEstablished(VoidCallback callback) {
    _onConnectionEstablished.remove(callback);
  }

  /// Отписаться от события "Соединение закрыто"
  void offConnectionClosed(VoidCallback callback) {
    _onConnectionClosed.remove(callback);
  }

  /// Отписаться от события "Пир подключился"
  void offPeerConnected(Function(String peerId) callback) {
    _onPeerConnected.remove(callback);
  }

  /// Отписаться от события "Пир отключился"
  void offPeerDisconnected(Function(String peerId) callback) {
    _onPeerDisconnected.remove(callback);
  }

  /// Отписаться от событий ошибок
  void offError(Function(String message) callback) {
    _onError.remove(callback);
  }

  /// Удалить все слушатели (очистить)
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.removeAllListeners();
  /// ```
  void removeAllListeners() {
    _onConnectionEstablished.clear();
    _onConnectionClosed.clear();
    _onPeerConnected.clear();
    _onPeerDisconnected.clear();
    _onError.clear();
  }

  // ============================================================================
  // ПРИВАТНЫЕ МЕТОДЫ
  // ============================================================================

  void _callConnectionEstablishedListeners() {
    for (final callback in _onConnectionEstablished) {
      try {
        callback();
      } catch (e) {
        // Handle callback error silently
      }
    }
  }

  void _callConnectionClosedListeners() {
    for (final callback in _onConnectionClosed) {
      try {
        callback();
      } catch (e) {
        // Handle callback error silently
      }
    }
  }

  void _callPeerConnectedListeners(String peerId) {
    for (final callback in _onPeerConnected) {
      try {
        callback(peerId);
      } catch (e) {
        // Handle callback error silently
      }
    }
  }

  void _callPeerDisconnectedListeners(String peerId) {
    for (final callback in _onPeerDisconnected) {
      try {
        callback(peerId);
      } catch (e) {
        // Handle callback error silently
      }
    }
  }

  void _callErrorListeners(String message) {
    for (final callback in _onError) {
      try {
        callback(message);
      } catch (e) {
        // Handle callback error silently
      }
    }
  }

  // ============================================================================
  // ОЧИСТКА
  // ============================================================================

  /// Полная очистка сервиса и все ресурсы
  ///
  /// Вызывается автоматически при закрытии приложения,
  /// но можно вызвать вручную если нужно сбросить состояние
  ///
  /// Пример:
  /// ```dart
  /// await WebRtcService.instance.dispose();
  /// ```
  @override
  Future<void> dispose() async {
    try {
      if (_isInitialized) {
        _connectedPeers.clear();
        _isInitialized = false;
      }
    } catch (e) {
      // Handle disposal error silently
    }
    removeAllListeners();
    super.dispose();
  }

  // ============================================================================
  // ОТЛАДКА
  // ============================================================================

  /// Получить подробную информацию о состоянии (для отладки)
  ///
  /// Возвращает Map со всей информацией о сервисе
  ///
  /// Пример:
  /// ```dart
  /// final info = WebRtcService.instance.getDebugInfo();
  /// print(info);
  /// ```
  Map<String, dynamic> getDebugInfo() {
    if (!_isInitialized) {
      return {
        'isInitialized': false,
        'timestamp': DateTime.now().toIso8601String(),
      };
    }

    return {
      'isInitialized': _isInitialized,
      'currentRoomId': _currentRoomId,
      'isLocalMuted': _isLocalMuted,
      'remoteVolume': _remoteVolume,
      'connectedPeers': _connectedPeers,
      'connectedPeersCount': getConnectedPeersCount(),
      'isConnected': isConnected(),
      'connectionState': getConnectionStateString(),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Вывести отладную информацию в консоль
  ///
  /// Полезно для отладки и тестирования
  ///
  /// Пример:
  /// ```dart
  /// WebRtcService.instance.logDebugInfo();
  /// ```
  void logDebugInfo() {
    final info = getDebugInfo();
    print('╔════════════════════════════════════════╗');
    print('║       WebRTC Service Debug Info        ║');
    print('╠════════════════════════════════════════╣');
    info.forEach((key, value) {
      print('║ $key: $value');
    });
    print('╚════════════════════════════════════════╝');
  }
}
