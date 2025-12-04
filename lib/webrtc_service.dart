import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_controller.dart';

/// Главный сервис для управления WebRTC функционалом.
///
/// WebRtcService отвечает за состояние звонка, список пиров и бизнес-логику.
/// WebRTCController отвечает за рендеры и привязку MediaStream -> RTCVideoRenderer.
class WebRtcService extends ChangeNotifier {
  WebRtcService._();
  static final WebRtcService instance = WebRtcService._();

  bool _isInitialized = false;
  int _currentRoomId = 0;
  bool _isLocalMuted = false;
  double _remoteVolume = 1.0;
  final List<String> _connectedPeers = [];

  // Listeners
  final List<VoidCallback> _onConnectionEstablished = [];
  final List<VoidCallback> _onConnectionClosed = [];
  final List<Function(String peerId)> _onPeerConnected = [];
  final List<Function(String peerId)> _onPeerDisconnected = [];
  final List<Function(String message)> _onError = [];

  /// Инициализация сервиса
  Future<void> initialize({
    required int roomId,
    Function(String)? onError,
  }) async {
    try {
      _currentRoomId = roomId;
      _isInitialized = true;
      _connectedPeers.clear();
      // Инициализируем контроллер рендереров
      await WebRTCController.instance.initialize();
      notifyListeners();
    } catch (e) {
      final errorMsg = 'Ошибка инициализации WebRTC: $e';
      onError?.call(errorMsg);
      _callErrorListeners(errorMsg);
      rethrow;
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'WebRtcService не инициализирован. Вызовите initialize() сначала.',
      );
    }
  }

  /// Начать вызов. Если передан список peerIds — предварительно создаём рендеры.
  Future<void> startCall({List<String>? peerIds}) async {
    _ensureInitialized();
    try {
      final activePeers = peerIds ?? [];

      if (activePeers.isNotEmpty) {
        for (final peerId in activePeers) {
          if (!_connectedPeers.contains(peerId)) {
            _connectedPeers.add(peerId);
            _callPeerConnectedListeners(peerId);
          }
          // Предварительная подготовка render'а для быстрой отрисовки UI
          try {
            await WebRTCController.instance.createRendererForPeer(peerId);
          } catch (_) {}
        }
        _callConnectionEstablishedListeners();
      }
      notifyListeners();
    } catch (e) {
      _callErrorListeners('Ошибка при начале вызова: $e');
      rethrow;
    }
  }

  /// Асинхронно завершает звонок и очищает ресурсы.
  Future<void> endCall() async {
    _ensureInitialized();
    try {
      // очищаем контроллер рендереров
      await WebRTCController.instance.disposeAll();
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

  void toggleMicrophone(bool isMuted) {
    _ensureInitialized();
    _isLocalMuted = isMuted;
    notifyListeners();
  }

  void muteMicrophone() => toggleMicrophone(true);
  void unmuteMicrophone() => toggleMicrophone(false);

  bool isMicrophoneMuted() {
    _ensureInitialized();
    return _isLocalMuted;
  }

  /// Установить общую громкость для всех удалённых пиров (сохранится в контроллере).
  Future<void> setRemoteVolume(double volume) async {
    _ensureInitialized();
    if (volume < 0.0 || volume > 1.0) {
      throw ArgumentError(
          'Громкость должна быть от 0.0 до 1.0, получено: $volume');
    }
    _remoteVolume = volume;
    for (final peerId in _connectedPeers) {
      WebRTCController.instance.setRemoteVolume(peerId, volume);
    }
    notifyListeners();
  }

  double getRemoteVolume() {
    _ensureInitialized();
    return _remoteVolume;
  }

  /// Отключить конкретного пира и удалить его рендерер.
  Future<void> disconnectPeer(String peerId) async {
    _ensureInitialized();
    try {
      _connectedPeers.remove(peerId);
      await WebRTCController.instance.removeRendererForPeer(peerId);
      _callPeerDisconnectedListeners(peerId);
      if (_connectedPeers.isEmpty) {
        _callConnectionClosedListeners();
      }
      notifyListeners();
    } catch (e) {
      _callErrorListeners('Ошибка при отключении пира $peerId: $e');
      rethrow;
    }
  }

  List<String> getConnectedPeers() {
    _ensureInitialized();
    return List.unmodifiable(_connectedPeers);
  }

  bool isPeerConnected(String peerId) {
    _ensureInitialized();
    return _connectedPeers.contains(peerId);
  }

  int getConnectedPeersCount() {
    _ensureInitialized();
    return _connectedPeers.length;
  }

  /// Получить видео рендерер для пира (синхронно) — null если ещё не создан.
  RTCVideoRenderer? getRemoteVideoRenderer(String peerId) {
    _ensureInitialized();
    if (!_connectedPeers.contains(peerId)) return null;
    return WebRTCController.instance.getRemoteRenderer(peerId);
  }

  /// Вернуть все рендереры (ключ = peerId)
  Map<String, RTCVideoRenderer> getAllRemoteVideoRenderers() {
    _ensureInitialized();
    return WebRTCController.instance.getAllRemoteRenderers();
  }

  /// Внешняя точка для присоединения MediaStream, полученного от PeerConnection.
  Future<void> attachRemoteStream(String peerId, MediaStream? stream) async {
    _ensureInitialized();

    if (!_connectedPeers.contains(peerId)) {
      _connectedPeers.add(peerId);
      _callPeerConnectedListeners(peerId);
      if (_connectedPeers.length == 1) _callConnectionEstablishedListeners();
    }

    await WebRTCController.instance.attachStreamToRenderer(peerId, stream);

    notifyListeners();
  }

  String getConnectionStateString() {
    if (!_isInitialized) return 'Не инициализировано';
    final status = isConnected() ? 'Подключено' : 'Отключено';
    final peers = getConnectedPeersCount();
    final mic = _isLocalMuted ? 'микрофон выключен' : 'микрофон включен';
    return '$status ($peers пиров, $mic)';
  }

  bool isConnected() => _isInitialized && _connectedPeers.isNotEmpty;
  bool isDisconnected() => !_isInitialized || _connectedPeers.isEmpty;

  // ---------------- Events ----------------
  void onConnectionEstablished(VoidCallback callback) =>
      _onConnectionEstablished.add(callback);
  void onConnectionClosed(VoidCallback callback) =>
      _onConnectionClosed.add(callback);
  void onPeerConnected(Function(String peerId) callback) =>
      _onPeerConnected.add(callback);
  void onPeerDisconnected(Function(String peerId) callback) =>
      _onPeerDisconnected.add(callback);
  void onError(Function(String message) callback) => _onError.add(callback);

  void offConnectionEstablished(VoidCallback callback) =>
      _onConnectionEstablished.remove(callback);
  void offConnectionClosed(VoidCallback callback) =>
      _onConnectionClosed.remove(callback);
  void offPeerConnected(Function(String peerId) callback) =>
      _onPeerConnected.remove(callback);
  void offPeerDisconnected(Function(String peerId) callback) =>
      _onPeerDisconnected.remove(callback);
  void offError(Function(String message) callback) => _onError.remove(callback);

  void removeAllListeners() {
    _onConnectionEstablished.clear();
    _onConnectionClosed.clear();
    _onPeerConnected.clear();
    _onPeerDisconnected.clear();
    _onError.clear();
  }

  void _callConnectionEstablishedListeners() {
    for (final callback in _onConnectionEstablished) {
      try {
        callback();
      } catch (e) {}
    }
  }

  void _callConnectionClosedListeners() {
    for (final callback in _onConnectionClosed) {
      try {
        callback();
      } catch (e) {}
    }
  }

  void _callPeerConnectedListeners(String peerId) {
    for (final callback in _onPeerConnected) {
      try {
        callback(peerId);
      } catch (e) {}
    }
  }

  void _callPeerDisconnectedListeners(String peerId) {
    for (final callback in _onPeerDisconnected) {
      try {
        callback(peerId);
      } catch (e) {}
    }
  }

  void _callErrorListeners(String message) {
    for (final callback in _onError) {
      try {
        callback(message);
      } catch (e) {}
    }
  }

  /// Синхронная dispose — запускает асинхронную очистку рендереров.
  @override
  void dispose() {
    unawaited(WebRTCController.instance.disposeAll());
    removeAllListeners();
    super.dispose();
  }

  /// Асинхронное завершение сервиса (дожидается очистки рендереров).
  Future<void> shutdown() async {
    try {
      await WebRTCController.instance.disposeAll();
    } catch (_) {}
    try {
      _connectedPeers.clear();
      _isInitialized = false;
    } catch (_) {}
    removeAllListeners();
  }

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
      'rendererCount': WebRTCController.instance.rendererCount,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

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
