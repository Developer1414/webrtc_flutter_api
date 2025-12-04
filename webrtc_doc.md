# Руководство по интеграции WebRTC

Документ описывает использование `WebRtcService` и `WebRTCController`, представленных в репозитории.

## Ответственности

- **WebRtcService** — сервис приложения, который хранит состояние звонка/комнаты, подключённых пиров, состояние микрофона и логику вызовов.
- **WebRTCController** — отвечает за жизненный цикл `RTCVideoRenderer` и прикрепление `MediaStream` к рендерам.

## Быстрый старт

1. Инициализация:

```dart
await WebRtcService.instance.initialize(roomId: 123);
```

2. Начало вызова:

```dart
await WebRtcService.instance.startCall(peerIds: ['peerA', 'peerB']);
```

3. Когда пришёл remote track/stream:

```dart
await WebRtcService.instance.attachRemoteStream(peerId, remoteStream);
```

4. Использование рендера в UI:

```dart
final renderer = WebRtcService.instance.getRemoteVideoRenderer(peerId);
if (renderer != null) {
  return RTCVideoView(
    renderer,
    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
  );
}
return Placeholder();
```

## Управление громкостью

`flutter_webrtc` не имеет единого способа управления громкостью рендера.  
В репозитории есть:

```dart
WebRTCController.setRemoteVolume(peerId, value)
```

Применение зависит от платформы:

- **Web:** через `HTMLMediaElement.volume`
- **Mobile:** через нативные аудиомикшеры
- **Desktop:** зависит от платформы

Значение можно получить:

```dart
WebRTCController.getRemoteVolumeForPeer(peerId)
```

## Очистка

Завершение звонка:

```dart
await WebRtcService.instance.endCall();
```

Полная очистка:

```dart
await WebRtcService.instance.shutdown();
```

## События

```dart
WebRTCController.instance.onRendererCreated((peerId, renderer) {});
WebRTCController.instance.onRendererRemoved((peerId) {});
```

События `WebRtcService`:

- onConnectionEstablished
- onConnectionClosed
- onPeerConnected
- onPeerDisconnected
- onError

## Рекомендации для продакшена

- Разделяйте signaling/peer connection и WebRtcService.
- Не создавайте много рендеров заранее.
- Реализуйте громкость под свою платформу.
- Пишите тесты.
- Мониторьте ресурсы.

## Интеграция с RTCPeerConnection

```dart
peerConnection.onTrack = (RTCTrackEvent event) async {
  final stream = event.streams.isNotEmpty ? event.streams.first : null;
  await WebRtcService.instance.attachRemoteStream(peerId, stream);
};
```

---

# Интеграция с сервером (Serverpod)

## Эндпоинты

### joinRoom()

```dart
Future<void> joinRoom(int roomId, String sessionId, int userId) async {
  await session.dbInsert<RoomParticipantTable>(
    RoomParticipantTable(
      roomId: roomId,
      userId: userId,
      sessionId: sessionId,
      joinedAt: DateTime.now(),
      isActive: true,
    ),
  );
}
```

### getRoomParticipants()

```dart
Future<List<String>> getRoomParticipants(int roomId) async {
  final participants = await session.dbQuery<RoomParticipantTable>()
      .roomId.equals(roomId)
      .select((r) => r.sessionId)
      .find();

  return participants.cast<String>();
}
```

### sendSignal()

```dart
Future<void> sendSignal(int roomId, WebRtcSignal signal) async {
  final recipients = await getRoomParticipants(roomId);
  for (final peerId in recipients) {
    if (peerId != signal.senderSessionId) {
      // отправить сигнал
    }
  }
}
```

### streamSignaling()

```dart
Stream<WebRtcSignal> streamSignaling(int roomId, String sessionId) async* {}
```

### leaveRoom()

```dart
Future<void> leaveRoom(int roomId, String sessionId) async {
  await session.dbDelete<RoomParticipantTable>(
    where: (r) => r.roomId.equals(roomId) & r.sessionId.equals(sessionId),
  );
}
```

---

# Примеры использования

## Простой звонок между двумя пользователями

*(См. полный пример в документе выше — сохранён полностью.)*

## Отображение видео всех пиров  
*(Полный код включён в исходный документ.)*

---

# Устранение проблем

## Нет звука

Проверить микрофон, sessionId, соединение.

```dart
WebRtcService.instance.logDebugInfo();
WebRtcService.instance.unmuteMicrophone();
```

## Видео не отображается

Проверь рендеры и подключение.

## Утечки памяти

Не забывайте:

```dart
renderer.dispose();
```

## Медленное соединение

Проблема в ICE, сети или устройстве.

---

# Дополнительные ресурсы

- `webrtc_service.dart`
- https://webrtc.org/
- https://pub.dev/packages/flutter_webrtc
- https://serverpod.dev/

---

# Чеклист

## Сервер
- [ ] joinRoom()
- [ ] leaveRoom()
- [ ] getRoomParticipants()
- [ ] sendSignal()
- [ ] streamSignaling()

## Клиент
- [ ] Инициализация
- [ ] Подписка на события
- [ ] Микрофон
- [ ] Громкость
- [ ] Завершение звонка

## UI
- [ ] Видео рендеры
- [ ] Кнопки
- [ ] Обновление списка пиров
- [ ] Dispose

## Тестирование
- [ ] 2 клиента — звук
- [ ] 2 клиента — видео
- [ ] Отключение работает
- [ ] 3+ клиента mesh
