# WebRTC Сервис

Полная документация по использованию WebRTC.

## 📚 Содержание

1. [Обзор](#обзор)
2. [Быстрый старт](#быстрый-старт)
3. [Архитектура](#архитектура)
4. [API Сервиса](#api-сервиса)
5. [Видео рендеринг](#видео-рендеринг)
6. [Интеграция с сервером](#интеграция-с-сервером)
7. [Примеры использования](#примеры-использования)
8. [Устранение проблем](#устранение-проблем)

---

## 🎬 Обзор

WebRTC позволяет клиентам общаться напрямую (P2P) без промежуточного сервера. Сервер только передает сигналы (offer/answer/ICE candidates) между клиентами.

### Что такое WebRtcService?

`WebRtcService` - это высокоуровневый сервис-обертка над WebRTC, который предоставляет простой и удобный API для:
- Инициализации соединения
- Управления вызовами
- Работы с микрофоном и аудио
- Управления пирами (подключенными пользователями)
- Отслеживания событий

### Архитектура решения

```
┌─────────────────────┐
│   Flutter UI        │  Отображает видео, кнопки управления
└──────────┬──────────┘
           │
┌──────────▼──────────────────────┐
│   WebRtcService (singleton)      │  Высокоуровневый API
│   - initialize()                 │  Управление вызовами
│   - startCall()                  │  События (onPeerConnected, etc)
│   - endCall()                    │
└──────────┬──────────────────────┘
           │
┌──────────▼──────────────────────┐
│   WebRTCController              │  Работает с P2P соединениями
│   - Создает RTCPeerConnection   │  Обрабатывает сигналы
│   - Обрабатывает медиа потоки   │
└──────────┬──────────────────────┘
           │
┌──────────▼──────────────────────┐
│   Signaling                │  Связь с сервером
│   (implements SignalingInterface)
│   - sendSignal(offer/answer/ICE)│
│   - streamSignaling()            │  Получает сигналы с сервера
└──────────┬──────────────────────┘
           │
┌──────────▼──────────────────────┐
│   Serverpod Server              │  Маршрутизирует сигналы
│   - joinRoom()                  │  Управляет сессиями
│   - leaveRoom()                 │  Хранит список участников
│   - sendSignal() → все пиры     │
│   - streamSignaling() → сигналы │
└─────────────────────────────────┘
```

---

## ⚡ Быстрый старт

### Шаг 1: Инициализация

```dart
// Инициализировать сервис для конкретной комнаты
await WebRtcService.instance.initialize(roomId: 123);

// Можно передать коллбэк для обработки ошибок
await WebRtcService.instance.initialize(
  roomId: 123,
  onError: (error) => print('Ошибка: $error'),
);
```

### Шаг 2: Подписка на события

```dart
// Пир подключился
WebRtcService.instance.onPeerConnected((peerId) {
  print('Пир подключился: $peerId');
  // Обновить UI, получить видео рендерер, и т.д.
});

// Пир отключился
WebRtcService.instance.onPeerDisconnected((peerId) {
  print('Пир отключился: $peerId');
  // Удалить видео из UI
});

// Ошибка
WebRtcService.instance.onError((message) {
  print('Ошибка WebRTC: $message');
});
```

### Шаг 3: Начать звонок

```dart
// Начать звонок (создать соединения со всеми в комнате)
await WebRtcService.instance.startCall();
```

### Шаг 4: Управление микрофоном

```dart
// Выключить микрофон
WebRtcService.instance.muteMicrophone();

// Включить микрофон
WebRtcService.instance.unmuteMicrophone();

// Переключить состояние
WebRtcService.instance.toggleMicrophone(isMuted: true);

// Проверить состояние
if (WebRtcService.instance.isLocalMuted) {
  print('Микрофон выключен');
}
```

### Шаг 5: Завершить звонок

```dart
// Завершить звонок
await WebRtcService.instance.endCall();
```

---

## 🏗️ Архитектура

### Mesh Топология (Сетевая топология)

Используется mesh топология - каждый клиент подключен прямо ко всем остальным:

```
Для 3 пользователей:

    ┌─────────┐
    │ User A  │
    └────┬────┘
         │    \
         │     \ (прямое P2P соединение)
         │      \
    ┌────┴──┐ ┌──┴────┐
    │ User B│─│User C  │
    └───────┘ └────────┘

Каждая стрелка = отдельное RTCPeerConnection
Audio идет напрямую между пирами (не через сервер)
```

### sessionId vs userId

| Параметр | Назначение | Пример |
|----------|-----------|---------|
| **userId** | Постоянный ID пользователя в системе | `987654` (Telegram ID) |
| **sessionId** | Временный ID для одного звонка (UUID) | `a1b2c3d4-...` |
| **Используется** | Отслеживание пользователей в БД | Идентификация пиров в WebRTC |

---

## 📱 API Сервиса

### Инициализация

```dart
/// Инициализировать сервис для комнаты
/// 
/// Параметры:
/// - roomId: ID комнаты (обязательно)
/// - onError: коллбэк для обработки ошибок (опционально)
Future<void> initialize({
  required int roomId,
  Function(String)? onError,
})

// Пример:
await WebRtcService.instance.initialize(roomId: 123);
```

### Управление вызовом

```dart
/// Начать звонок (создать соединения со всеми)
Future<void> startCall()

/// Завершить звонок (закрыть все соединения)
Future<void> endCall()

// Примеры:
await WebRtcService.instance.startCall();
await WebRtcService.instance.endCall();
```

### Управление микрофоном

```dart
/// Включить/выключить микрофон
void toggleMicrophone(bool isMuted)

/// Выключить микрофон
void muteMicrophone()

/// Включить микрофон
void unmuteMicrophone()

/// Проверить выключен ли микрофон
bool isMicrophoneMuted() → bool

// Примеры:
WebRtcService.instance.toggleMicrophone(true);  // Выключить
WebRtcService.instance.muteMicrophone();        // Выключить
WebRtcService.instance.unmuteMicrophone();      // Включить
if (WebRtcService.instance.isMicrophoneMuted()) print('Выключен');
```

### Управление громкостью

```dart
/// Установить громкость удаленных участников (0.0 - 1.0)
Future<void> setRemoteVolume(double volume)

/// Получить текущую громкость
double getRemoteVolume() → double

// Примеры:
await WebRtcService.instance.setRemoteVolume(0.5);  // 50%
await WebRtcService.instance.setRemoteVolume(1.0);  // 100%
final volume = WebRtcService.instance.getRemoteVolume();
```

### Управление пирами

```dart
/// Получить список подключенных пиров
List<String> getConnectedPeers() → List<String>

/// Проверить подключен ли конкретный пир
bool isPeerConnected(String peerId) → bool

/// Получить количество подключенных пиров
int getConnectedPeersCount() → int

/// Отключить конкретного пира
Future<void> disconnectPeer(String peerId)

// Примеры:
final peers = WebRtcService.instance.getConnectedPeers();
if (WebRtcService.instance.isPeerConnected('peer_123')) {
  print('Пир подключен');
}
final count = WebRtcService.instance.getConnectedPeersCount();
await WebRtcService.instance.disconnectPeer('peer_123');
```

### Информация о состоянии

```dart
/// Проверить подключено ли соединение
bool isConnected() → bool

/// Проверить отключено ли соединение
bool isDisconnected() → bool

/// Получить строковое описание состояния
String getConnectionStateString() → String

// Примеры:
if (WebRtcService.instance.isConnected()) {
  print('Мы в звонке!');
}
print(WebRtcService.instance.getConnectionStateString());
// Вывод: "Подключено (2 пира, микрофон включен)"
```

### Свойства (Getters)

```dart
/// Инициализирован ли сервис
bool get isInitialized

/// ID текущей комнаты
int get currentRoomId

/// Выключен ли микрофон
bool get isLocalMuted

/// Текущая громкость (0.0-1.0)
double get remoteVolume

/// Список подключенных пиров
List<String> get connectedPeers

// Примеры:
if (WebRtcService.instance.isInitialized) {
  print('Комната: ${WebRtcService.instance.currentRoomId}');
}
if (WebRtcService.instance.isLocalMuted) {
  print('Микрофон выключен');
}
```

### События

```dart
/// Подписаться на событие "Соединение установлено"
void onConnectionEstablished(VoidCallback callback)

/// Подписаться на событие "Соединение закрыто"
void onConnectionClosed(VoidCallback callback)

/// Подписаться на событие "Пир подключился"
void onPeerConnected(Function(String peerId) callback)

/// Подписаться на событие "Пир отключился"
void onPeerDisconnected(Function(String peerId) callback)

/// Подписаться на события ошибок
void onError(Function(String message) callback)

// Примеры:
WebRtcService.instance.onConnectionEstablished(() {
  print('Соединение установлено');
});

WebRtcService.instance.onPeerConnected((peerId) {
  setState(() => peers.add(peerId));
});

WebRtcService.instance.onError((message) {
  showSnackBar('Ошибка: $message');
});
```

### Отписка от событий

```dart
/// Отписаться от события
void offConnectionEstablished(VoidCallback callback)
void offConnectionClosed(VoidCallback callback)
void offPeerConnected(Function(String peerId) callback)
void offPeerDisconnected(Function(String peerId) callback)
void offError(Function(String message) callback)

/// Удалить все слушатели
void removeAllListeners()
```

### Отладка

```dart
/// Получить информацию о состоянии (для отладки)
Map<String, dynamic> getDebugInfo() → Map

/// Вывести отладную информацию в консоль
void logDebugInfo()

// Примеры:
final info = WebRtcService.instance.getDebugInfo();
print(info['connectedPeersCount']);  // Количество пиров

WebRtcService.instance.logDebugInfo();
// Вывод:
// ╔════════════════════════════════════════╗
// ║       WebRTC Service Debug Info        ║
// ╠════════════════════════════════════════╣
// ║ isInitialized: true
// ║ currentRoomId: 123
// ║ connectedPeersCount: 2
// ...
```

---

## 📹 Видео рендеринг

### Как отобразить видео от других участников

#### Получение рендерера

```dart
// Получить видео рендерер для конкретного пира
// (Требует доступа к WebRTCController)
final RTCVideoRenderer? renderer = 
    WebRTCController.instance.getRemoteRenderer(peerId);
```

#### Отображение в UI

```dart
// Самый простой способ
if (renderer != null) {
  RTCVideoView(renderer)
}

// С оформлением
Container(
  decoration: BoxDecoration(
    color: Colors.black,
    borderRadius: BorderRadius.circular(12),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: renderer != null
        ? RTCVideoView(renderer)
        : Center(child: CircularProgressIndicator()),
  ),
)
```

#### В GridView (сетка со всеми пирами)

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1,
  ),
  itemCount: peers.length,
  itemBuilder: (context, index) {
    final peerId = peers[index];
    final renderer = WebRTCController.instance
        .getRemoteRenderer(peerId);

    return Container(
      color: Colors.black,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: renderer != null
            ? RTCVideoView(renderer)
            : Center(child: Icon(Icons.person, color: Colors.grey)),
      ),
    );
  },
)
```

#### Важно знать о RTCVideoRenderer

- **Создание:** Создается автоматически когда приходит видео поток от пира
- **Инициализация:** Должен быть инициализирован перед использованием
- **Использование:** Передается в RTCVideoView для отображения
- **Очистка:** Обязательно вызвать `renderer.dispose()` при отключении пира
- **Жизненный цикл:** После dispose() рендерер нельзя использовать заново

```dart
// ✅ Правильно:
@override
void dispose() {
  for (var renderer in renderers.values) {
    renderer.dispose();
  }
  super.dispose();
}

// ❌ Неправильно:
// Забыли вызвать dispose() - утечка памяти!
```

---

## 🌐 Интеграция с сервером

### Что сервер должен делать

Сервер Serverpod должен реализовать эти эндпоинты:

#### 1. joinRoom() - Присоединиться к комнате

```dart
// На сервере (room_endpoint.dart)
Future<void> joinRoom(int roomId, String sessionId, int userId) async {
  // 1. Сохранить участника в БД
  await session.dbInsert<RoomParticipantTable>(
    RoomParticipantTable(
      roomId: roomId,
      userId: userId,
      sessionId: sessionId,
      joinedAt: DateTime.now(),
      isActive: true,
    ),
  );
  
  // 2. Уведомить других участников
  // (отправить broadcast)
}
```

#### 2. getRoomParticipants() - Получить список участников

```dart
// На сервере
Future<List<String>> getRoomParticipants(int roomId) async {
  // Вернуть список sessionId всех активных участников
  final participants = await session.dbQuery<RoomParticipantTable>()
      .roomId.equals(roomId)
      .select((r) => r.sessionId)
      .find();
  
  return participants.cast<String>();
}
```

На клиенте это вызывается автоматически при `startCall()`.

#### 3. sendSignal() - Отправить сигнал

```dart
// На сервере
Future<void> sendSignal(int roomId, WebRtcSignal signal) async {
  // Маршрутизировать сигнал:
  // - Если targetSessionId указан → отправить только ему
  // - Иначе → отправить всем кроме отправителя
  
  final recipients = await getRoomParticipants(roomId);
  for (final peerId in recipients) {
    if (peerId != signal.senderSessionId) {
      // Отправить сигнал пиру
    }
  }
}
```

#### 4. streamSignaling() - Получить поток сигналов

```dart
// На сервере
Stream<WebRtcSignal> streamSignaling(int roomId, String sessionId) async* {
  // Возвращает stream сигналов для конкретной сессии
  // Это long-lived connection (открыта все время вызова)
  
  // Когда сигнал приходит для этой сессии → yield
  // Когда сессия отключается → close stream
}
```

На клиенте слушается автоматически.

#### 5. leaveRoom() - Покинуть комнату

```dart
// На сервере
Future<void> leaveRoom(int roomId, String sessionId) async {
  // 1. Удалить участника из БД
  await session.dbDelete<RoomParticipantTable>(
    where: (r) => r.roomId.equals(roomId) & r.sessionId.equals(sessionId),
  );
  
  // 2. Закрыть signal stream для этой сессии
  // 3. Уведомить остальных пиров
}
```

### Процесс соединения

```
Клиент A                Сервер              Клиент B
    |                     |                    |
  startCall()             |                    |
    |                     |                    |
  joinRoom() ────────────→|                    |
    |                     |                    |
  getRoomParticipants()   |                    |
    |────→|               |                    |
    |←────| (вернул B)    |                    |
    |                     |                    |
  streamSignaling()       |         streamSignaling()
    |────→| (открыл)      |←────────────| (открыл)
    |     |       (слушает)       (слушает)
    |     |                       |
  createOffer()           |       |
  sendSignal(offer) ─────→|───→ onSignal(offer)
    |                     |   createAnswer()
    |                     |   sendSignal(answer)
    |←────answer────────|←────|
    |                     |       |
    |  Exchange ICE candidates  |
    |←═════════════════════════→|
    |                     |       |
    | Audio flows P2P (не через сервер)
    |
  endCall()               |
    |                     |
  leaveRoom() ───────────→|
    |                     |──→ closeStream
    |                     |───→ onUserLeft()
```

---

## 💡 Примеры использования

### Пример 1: Простой звонок между двумя пользователями

```dart
class SimpleCallPage extends StatefulWidget {
  final int roomId;
  
  @override
  State<SimpleCallPage> createState() => _SimpleCallPageState();
}

class _SimpleCallPageState extends State<SimpleCallPage> {
  bool _isMicMuted = false;
  List<String> _peers = [];

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    // 1. Инициализировать
    await WebRtcService.instance.initialize(roomId: widget.roomId);

    // 2. Подписаться на события
    WebRtcService.instance.onPeerConnected((peerId) {
      setState(() => _peers.add(peerId));
    });

    WebRtcService.instance.onPeerDisconnected((peerId) {
      setState(() => _peers.remove(peerId));
    });

    // 3. Начать звонок
    await WebRtcService.instance.startCall();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Звонок - ${_peers.length} участников'),
      ),
      body: Column(
        children: [
          // Информация
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_peers.isEmpty)
                    Text('Ожидание подключения...')
                  else
                    for (var peer in _peers)
                      Chip(label: Text('Пир: $peer')),
                ],
              ),
            ),
          ),

          // Контролы
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Микрофон
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isMicMuted = !_isMicMuted);
                    WebRtcService.instance
                        .toggleMicrophone(_isMicMuted);
                  },
                  icon: Icon(_isMicMuted ? Icons.mic_off : Icons.mic),
                  label: Text(_isMicMuted ? 'Включить' : 'Выключить'),
                ),

                // Завершить
                ElevatedButton.icon(
                  onPressed: () async {
                    await WebRtcService.instance.endCall();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.call_end),
                  label: Text('Завершить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WebRtcService.instance.removeAllListeners();
    super.dispose();
  }
}
```

### Пример 2: Отображение видео всех пиров

```dart
class VideoCallPage extends StatefulWidget {
  final int roomId;

  @override
  State<VideoCallPage> createState() => _VideoCallPageState();
}

class _VideoCallPageState extends State<VideoCallPage> {
  List<String> _peers = [];
  bool _isMicMuted = false;
  double _remoteVolume = 1.0;

  @override
  void initState() {
    super.initState();
    _startCall();
  }

  Future<void> _startCall() async {
    await WebRtcService.instance.initialize(roomId: widget.roomId);

    WebRtcService.instance.onPeerConnected((peerId) {
      setState(() => _peers.add(peerId));
    });

    WebRtcService.instance.onPeerDisconnected((peerId) {
      setState(() => _peers.remove(peerId));
    });

    await WebRtcService.instance.startCall();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Видео конференция')),
      body: Column(
        children: [
          // Сетка видео
          Expanded(
            child: _peers.isEmpty
                ? Center(child: Text('Нет участников'))
                : GridView.builder(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                    ),
                    itemCount: _peers.length,
                    itemBuilder: (context, index) {
                      final peerId = _peers[index];
                      // TODO: Получить видео рендерер
                      // final renderer = WebRTCController.instance
                      //     .getRemoteRenderer(peerId);

                      return Container(
                        color: Colors.black,
                        child: Center(
                          child: Text('Видео: $peerId'),
                        ),
                      );
                    },
                  ),
          ),

          // Контрольная панель
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Громкость
                Row(
                  children: [
                    Icon(Icons.volume_down),
                    Expanded(
                      child: Slider(
                        value: _remoteVolume,
                        onChanged: (v) async {
                          await WebRtcService.instance
                              .setRemoteVolume(v);
                          setState(() => _remoteVolume = v);
                        },
                      ),
                    ),
                    Icon(Icons.volume_up),
                  ],
                ),

                SizedBox(height: 16),

                // Кнопки
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() => _isMicMuted = !_isMicMuted);
                        WebRtcService.instance
                            .toggleMicrophone(_isMicMuted);
                      },
                      icon: Icon(_isMicMuted
                          ? Icons.mic_off
                          : Icons.mic),
                      label: Text('Микрофон'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await WebRtcService.instance.endCall();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.call_end),
                      label: Text('Завершить'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WebRtcService.instance.removeAllListeners();
    super.dispose();
  }
}
```

---

## 🐛 Устранение проблем

### Проблема: Нет звука

**Возможные причины:**
1. Микрофон выключен: `WebRtcService.instance.isMicrophoneMuted()`
2. Неверный sessionId в сигналах
3. Соединение не установлено

**Решение:**
```dart
// Проверить состояние
WebRtcService.instance.logDebugInfo();

// Включить микрофон
WebRtcService.instance.unmuteMicrophone();

// Проверить подключенных пиров
final peers = WebRtcService.instance.getConnectedPeers();
print('Подключено пиров: ${peers.length}');
```

### Проблема: Видео не отображается

**Возможные причины:**
1. Рендерер еще не инициализирован
2. Видео отключено на стороне отправителя
3. Пир еще не подключился

**Решение:**
```dart
// Проверить что пир подключен
if (WebRtcService.instance.isPeerConnected(peerId)) {
  // Попробовать получить рендерер
  final renderer = WebRTCController.instance
      .getRemoteRenderer(peerId);
  
  if (renderer != null) {
    // Отобразить видео
  } else {
    // Показать загрузку
    CircularProgressIndicator();
  }
}
```

### Проблема: Утечка памяти

**Причина:** RTCVideoRenderer не очищен

**Решение:**
```dart
@override
void dispose() {
  // Очистить все рендерры
  for (var renderer in renderers.values) {
    renderer.dispose();
  }
  
  // Отписаться от событий
  WebRtcService.instance.removeAllListeners();
  
  super.dispose();
}
```

### Проблема: Подключение медленное

**Причины:**
1. Много ICE candidates
2. Плохое соединение
3. Слабое устройство

**Решение:**
```dart
// Уменьшить громкость для проверки сети
await WebRtcService.instance.setRemoteVolume(0.5);

// Отслеживать статус
WebRtcService.instance.logDebugInfo();
```

---

## 📖 Дополнительные ресурсы

- `webrtc_service.dart` - Исходный код сервиса
- WebRTC официальная документация: https://webrtc.org/
- flutter_webrtc: https://pub.dev/packages/flutter_webrtc
- Serverpod документация: https://serverpod.dev/

---

## ✅ Контрольный список реализации

### На сервере (Serverpod):
- [ ] Создана таблица RoomParticipantTable
- [ ] Реализован endpoint joinRoom()
- [ ] Реализован endpoint leaveRoom()
- [ ] Реализован endpoint getRoomParticipants()
- [ ] Реализован endpoint sendSignal()
- [ ] Реализован stream streamSignaling()

### На клиенте (Flutter):
- [ ] WebRtcService инициализируется при входе в комнату
- [ ] Подписаны на события (onPeerConnected, onPeerDisconnected)
- [ ] Управление микрофоном работает
- [ ] Управление громкостью работает
- [ ] Завершение звонка работает корректно

### UI:
- [ ] Отображение видео рендереров
- [ ] Кнопки управления (микрофон, громкость, завершить)
- [ ] Обновление списка пиров при подключении/отключении
- [ ] Правильная очистка ресурсов (dispose)

### Тестирование:
- [ ] Тест с 2 клиентами - звук работает
- [ ] Тест с 2 клиентами - видео отображается
- [ ] Тест отключения - второй клиент получает уведомление
- [ ] Тест с 3+ клиентами - mesh сеть работает

---

**Всё готово к использованию! Удачи! 🚀**
