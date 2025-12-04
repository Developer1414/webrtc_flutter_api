import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// WebRTCController
///
/// Контроллер, отвечающий за управление RTCVideoRenderer и привязанных
/// к ним удалённых MediaStream'ов. Singleton: WebRTCController.instance.
///
/// Задачи:
/// - lifecycle / инициализация RTCVideoRenderer per-peer
/// - attach/detach MediaStream -> renderer
/// - хранение per-peer метаданных (volume)
/// - события создания/удаления рендерера
///
/// Замечание: контроллер не выполняет сигнализацию и не управляет RTCPeerConnection.
class WebRTCController {
  WebRTCController._();
  static final WebRTCController instance = WebRTCController._();

  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, double> _volumes = {};

  final List<void Function(String peerId, RTCVideoRenderer renderer)>
      _onRendererCreated = [];
  final List<void Function(String peerId)> _onRendererRemoved = [];

  bool _initialized = false;

  /// Инициализация контроллера (безопасно вызывать несколько раз)
  Future<void> initialize() async {
    if (_initialized) return;
    // Точка расширения для платформенных инициализаций.
    _initialized = true;
  }

  /// Создаёт и инициализирует RTCVideoRenderer для пира, если его ещё нет.
  Future<RTCVideoRenderer> createRendererForPeer(String peerId) async {
    if (peerId.isEmpty) {
      throw ArgumentError('peerId cannot be empty');
    }
    final existing = _renderers[peerId];
    if (existing != null) return existing;

    final renderer = RTCVideoRenderer();
    try {
      await renderer.initialize();
      _renderers[peerId] = renderer;
      _notifyRendererCreated(peerId, renderer);
      return renderer;
    } catch (e) {
      // очистка частично созданного объекта
      try {
        await renderer.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  /// Возвращает уже существующий рендерер или null.
  RTCVideoRenderer? getRemoteRenderer(String peerId) {
    return _renderers[peerId];
  }

  /// Получить или создать рендерер.
  Future<RTCVideoRenderer> getOrCreateRemoteRenderer(String peerId) async {
    final existing = getRemoteRenderer(peerId);
    if (existing != null) return existing;
    return await createRendererForPeer(peerId);
  }

  /// Присоединяет MediaStream к рендереру (создаст рендерер если нужно).
  Future<void> attachStreamToRenderer(
      String peerId, MediaStream? stream) async {
    if (peerId.isEmpty) throw ArgumentError('peerId cannot be empty');
    final renderer = await getOrCreateRemoteRenderer(peerId);
    try {
      renderer.srcObject = stream;
    } catch (e) {
      if (kDebugMode) {
        print('WebRTCController: failed to attach stream to $peerId: $e');
      }
    }
  }

  /// Удаляет рендерер и освобождает ресурсы.
  Future<void> removeRendererForPeer(String peerId) async {
    final renderer = _renderers.remove(peerId);
    if (renderer == null) return;
    try {
      renderer.srcObject = null;
    } catch (_) {}
    try {
      await renderer.dispose();
    } catch (_) {}
    _volumes.remove(peerId);
    _notifyRendererRemoved(peerId);
  }

  /// Возвращает неизменяемую копию всех рендереров.
  Map<String, RTCVideoRenderer> getAllRemoteRenderers() {
    return Map.unmodifiable(_renderers);
  }

  /// Сохраняет желаемый уровень громкости для пира (0.0 - 1.0).
  /// Замечание: flutter_webrtc не предоставляет API для установки громкости
  /// per-renderer на всех платформах. Это значение нужно применить платформенно.
  void setRemoteVolume(String peerId, double volume) {
    if (peerId.isEmpty) throw ArgumentError('peerId cannot be empty');
    final v = volume.clamp(0.0, 1.0);
    _volumes[peerId] = v;
  }

  /// Получить сохранённую громкость (по умолчанию 1.0).
  double getRemoteVolumeForPeer(String peerId) => _volumes[peerId] ?? 1.0;

  /// Очистить все рендереры и ресурсы.
  Future<void> disposeAll() async {
    final keys = List<String>.from(_renderers.keys);
    for (final key in keys) {
      await removeRendererForPeer(key);
    }
    _renderers.clear();
    _volumes.clear();
    _initialized = false;
  }

  // ---------------- Event API ----------------
  void onRendererCreated(void Function(String peerId, RTCVideoRenderer) cb) {
    _onRendererCreated.add(cb);
  }

  void offRendererCreated(void Function(String peerId, RTCVideoRenderer) cb) {
    _onRendererCreated.remove(cb);
  }

  void onRendererRemoved(void Function(String peerId) cb) {
    _onRendererRemoved.add(cb);
  }

  void offRendererRemoved(void Function(String peerId) cb) {
    _onRendererRemoved.remove(cb);
  }

  void _notifyRendererCreated(String peerId, RTCVideoRenderer r) {
    for (final cb in List.from(_onRendererCreated)) {
      try {
        cb(peerId, r);
      } catch (e) {
        if (kDebugMode) print('onRendererCreated callback error: $e');
      }
    }
  }

  void _notifyRendererRemoved(String peerId) {
    for (final cb in List.from(_onRendererRemoved)) {
      try {
        cb(peerId);
      } catch (e) {
        if (kDebugMode) print('onRendererRemoved callback error: $e');
      }
    }
  }

  /// Количество созданных рендереров (для отладки)
  int get rendererCount => _renderers.length;
}
