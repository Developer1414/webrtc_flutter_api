import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Контроллер, отвечающий за управление рендерерами и удалёнными медиа-потоками.
///
/// Реализован как singleton: WebRTCController.instance
/// Предоставляет API для:
/// - создания/инициализации RTCVideoRenderer для удалённого пира
/// - присоединения MediaStream к рендереру
/// - удаления и очистки рендереров
/// - получения списка рендереров (для использования в WebRtcService)
///
/// Примечание: этот контроллер не пытается заниматься сигнализацией или
/// установкой peer connection — он фокусируется на рендерах и управлении
/// MediaStream/рендерами, ��тобы WebRtcService и UI могли с ними работать.
class WebRTCController {
  WebRTCController._();
  static final WebRTCController instance = WebRTCController._();

  final Map<String, RTCVideoRenderer> _renderers = {};
  final Map<String, double> _volumes = {};

  bool _initialized = false;

  /// Инициализация контроллера (может быть вызвана один раз при старте приложения)
  Future<void> initialize() async {
    if (_initialized) return;
    // На текущий момент специфичная инициализация не требуется,
    // но оставляем метод для расширяемости и будущих нужд.
    _initialized = true;
  }

  /// Создаёт и инициализирует RTCVideoRenderer для пира, если его ещё нет.
  /// Возвращает инициализированный рендерер.
  Future<RTCVideoRenderer> createRendererForPeer(String peerId) async {
    if (_renderers.containsKey(peerId)) {
      return _renderers[peerId]!;
    }

    final renderer = RTCVideoRenderer();
    try {
      await renderer.initialize();
      _renderers[peerId] = renderer;
    } catch (e) {
      // В случае ошибки очищаем созданный объект
      try {
        await renderer.dispose();
      } catch (_) {}
      rethrow;
    }
    return renderer;
  }

  /// Получить уже существующий рендерер для пира или null если его нет.
  ///
  /// Этот синхронный метод полезен для использования в UI, где вы хотите
  /// сразу взять рендерер если он уже создан (см. WebRtcService).
  RTCVideoRenderer? getRemoteRenderer(String peerId) {
    return _renderers[peerId];
  }

  /// Асинхронный вариант получения рендерера: создаст рендерер если его нет.
  Future<RTCVideoRenderer> getOrCreateRemoteRenderer(String peerId) async {
    final existing = getRemoteRenderer(peerId);
    if (existing != null) return existing;
    return await createRendererForPeer(peerId);
  }

  /// Присоединяет MediaStream к рендереру пира (если рендерер создан).
  /// Если рендерера нет, метод попытается его создать.
  Future<void> attachStreamToRenderer(String peerId, MediaStream stream) async {
    final renderer = await getOrCreateRemoteRenderer(peerId);
    try {
      renderer.srcObject = stream;
    } catch (e) {
      // Если присоединение не удалось, просто логируем (не кидаем)
      if (kDebugMode) {
        print('WebRTCController: failed to attach stream to $peerId: $e');
      }
    }
  }

  /// Отсоединяет поток и удаляет рендерер для пира.
  Future<void> removeRendererForPeer(String peerId) async {
    final renderer = _renderers.remove(peerId);
    if (renderer != null) {
      try {
        renderer.srcObject = null;
      } catch (_) {}
      try {
        await renderer.dispose();
      } catch (_) {}
    }
    _volumes.remove(peerId);
  }

  /// Возвращает Map всех рендереров (неизменяемую копию).
  Map<String, RTCVideoRenderer> getAllRemoteRenderers() {
    return Map.unmodifiable(_renderers);
  }

  /// Устанавливает желаемую громкость для конкретного пира (0.0 - 1.0).
  ///
  /// Примечание: flutter_webrtc не предоставляет прямого API для установки
  /// громкости в RTCVideoRenderer. Здесь мы сохраняем значение в памяти
  /// и даём возможность UI/плееру считать его и применить (например, к
  /// HTML audio элементу в web или к нативным аудио-API на платформе).
  void setRemoteVolume(String peerId, double volume) {
    final v = volume.clamp(0.0, 1.0);
    _volumes[peerId] = v;
  }

  /// Получить сохранённую громкость для пира или null.
  double? getRemoteVolumeForPeer(String peerId) => _volumes[peerId];

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

  /// Для отладки: возвращает количество созданных рендереров
  int get rendererCount => _renderers.length;
}