Конечно, я подготовлю документацию для вашего пакета `easy_voice_package.dart` в виде чистого текста, который вы сможете скопировать и вставить в Markdown файл.

Вот полная документация:

# EasyVoice SDK для WebRTC (Flutter/Serverpod)

EasyVoice SDK — это минималистичная библиотека для создания голосовых звонков "точка-точка" (P2P Mesh) в приложениях Flutter. Она полностью абстрагирует WebRTC и предоставляет чистый API для управления комнатами, микрофоном и громкостью.

## Архитектура

SDK разделен на две части:
1. **`VoiceServerEngine` (Serverpod/Backend)**: Обрабатывает логику комнат (создание, присоединение, пароли) и маршрутизирует WebRTC сигналы.
2. **`VoiceClient` (Flutter/Frontend)**: Управляет микрофоном, WebRTC-соединениями и предоставляет стримы событий.
Для работы требуется реализовать интерфейс `VoiceSignalingTransport`, который свяжет эти две части через ваш Serverpod Endpoint. 

## I. Интеграция Serverpod (Backend)

Поместите класс `VoiceServerEngine` в ваш Serverpod-проект (например, в папку `lib/src/logic`).

### 1. Инициализация Endpoint

В вашем Serverpod Endpoint (например, `voice_endpoint.dart`):


```
import 'package:serverpod/serverpod.dart';
import '../logic/easy_voice_package.dart'; // Путь к пакету

class VoiceEndpoint extends Endpoint {
  // Инициализация движка комнат
  static final _engine = VoiceServerEngine();

  // Основной метод для обработки всех клиентских запросов
  Future<dynamic> voiceAction(Session session, Map<String, dynamic> data) async {
    // Получение ID аутентифицированного пользователя
    final userId = session.authenticated!.userId.toString();
    
    // Передаем запрос движку. Движок сам обработает 'create', 'join', 'signal' и т'д.
    final result = _engine.handleEvent(userId, data);

    // Если это сигнал, Serverpod должен переслать его другому пользователю
    if (result is Map && result['action'] == 'forward_signal') {
      // Пример использования Serverpod Messaging
      session.messages.sendToUser(
        result['to'], // ID пользователя-получателя
        'voice_signal', // Канал для WebRTC сигналов
        result['data'], // Данные сигнала (offer, answer, candidate)
      );
      return {'status': 'signal_forwarded'};
    }

    return result;
  }
}
```

## II. Интеграция Flutter (Frontend)

### 1. Реализация Транспорта

Создайте класс, который реализует `VoiceSignalingTransport`, чтобы связать `VoiceClient` с Serverpod.


```
import 'package:serverpod_flutter/serverpod_flutter.dart';
import 'package:easy_voice_package/easy_voice_package.dart'; // Путь к пакету

class ServerpodTransport implements VoiceSignalingTransport {
  final Client _client;
  final String _currentUserId;
  final StreamController<VoiceSignalData> _incomingSignals = StreamController.broadcast();

  @override
  Stream<VoiceSignalData> get incomingSignals => _incomingSignals.stream;

  ServerpodTransport(this._client, this._currentUserId) {
    // Подписываемся на Serverpod Messaging для входящих сигналов
    _client.openStreamingConnection(
      // Канал должен совпадать с тем, что отправляет Serverpod Endpoint
      onMessage: (message) {
        if (message.channel == 'voice_signal') {
          final data = message.data as Map<String, dynamic>;
          _incomingSignals.add(VoiceSignalData(
            data['from'], // От кого
            data['data'], // offer, answer, candidate
          ));
        }
      }
    );
  }

  @override
  Future<void> connect() async {
    // Подключение к Serverpod Streaming уже произошло в конструкторе
  }

  @override
  Future<dynamic> sendRequest(String type, dynamic payload) async {
    // Отправляем все запросы на Serverpod Endpoint
    return await _client.voiceAction({'type': type, 'payload': payload});
  }
}
```

### 2. Использование VoiceClient

В вашем Flutter-приложении:


```
// Инициализация
final transport = ServerpodTransport(myServerpodClient, myAuthUserId);
final voiceClient = VoiceClient(transport: transport);
await voiceClient.init();

// Управление комнатой
// Создать комнату с паролем
await voiceClient.createRoom('MySecretRoom', password: '123', maxPeers: 5);
// Войти в существующую
// await voiceClient.joinRoom('MySecretRoom', password: '123');

// Слушать события для обновления UI
voiceClient.participantsStream.listen((peers) {
  // Обновляем список участников в UI
  print('Участники: $peers');
});

voiceClient.errorStream.listen((error) {
  // Показываем ошибку пользователю
  print('Ошибка SDK: $error');
});

// Управление микрофоном
bool isMuted = false;
voiceClient.toggleMyMic(!isMuted);

// Управление громкостью конкретного собеседника (Mute/Unmute)
String peerIdToMute = 'some_user_id';
voiceClient.muteParticipant(peerIdToMute, true); // Отключить звук
voiceClient.muteParticipant(peerIdToMute, false); // Включить звук

// Регулировка громкости (0.0 - 1.0)
voiceClient.setParticipantVolume(peerIdToMute, 0.5); 

// Выход
voiceClient.leave('MySecretRoom');
```

## III. API VoiceClient (Полный список методов)

| Метод | Описание |
| :--- | :--- |
| `init()` | Инициализирует WebRTC, запрашивает доступ к микрофону и подключает транспорт. Должен быть вызван один раз. |
| `createRoom(id, {password, maxPeers})` | Создает комнату на сервере с указанными параметрами, затем автоматически входит в нее. |
| `joinRoom(id, {password})` | Присоединяется к существующей комнате. Инициирует WebRTC соединения со всеми текущими участниками. |
| `leave(roomId)` | Завершает все WebRTC соединения, останавливает локальный аудиопоток и уведомляет сервер о выходе. |
| `toggleMyMic(isEnabled)` | Включает/выключает ваш локальный микрофон. |
| `muteParticipant(peerId, isMuted)` | Отключает/включает аудиопоток от конкретного участника **для вас**. |
| `setParticipantVolume(peerId, volume)` | Устанавливает громкость аудиопотока для конкретного участника (от 0.0 до 1.0). |
| `participantsStream` | **Stream:** Транслирует обновленный список ID участников, находящихся в комнате (тех, с кем установлено P2P соединение). |
| `errorStream` | **Stream:** Транслирует строковые сообщения об ошибках (например, ошибка доступа к микрофону, ошибка WebRTC). |