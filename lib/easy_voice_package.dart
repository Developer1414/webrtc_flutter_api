import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// ==========================================
// ЧАСТЬ 1: СЕРВЕРНАЯ ЛОГИКА (Для Serverpod)
// ==========================================

/// Класс, который разработчик инициализирует у себя на сервере (в Endpoint).
/// Он берет на себя всю логику комнат.
class VoiceServerEngine {
  final Map<String, _Room> _rooms = {};

  /// Обработка запросов от клиента.
  /// developer's endpoint просто передает сюда data.
  dynamic handleEvent(String userId, Map<String, dynamic> data) {
    final type = data['type'];
    final payload = data['payload'];

    switch (type) {
      case 'create':
        return _createRoom(payload['roomId'], payload['config']);
      case 'join':
        return _joinRoom(payload['roomId'], userId, payload['password']);
      case 'leave':
        _leaveRoom(payload['roomId'], userId);
        return {'status': 'left'};
      case 'signal':
        // В реальном Serverpod здесь возвращается инструкция для отправки сообщения другому пиру
        return {
          'action': 'forward_signal',
          'to': payload['to'],
          'data': payload['data']
        };
      default:
        throw Exception('Unknown voice event');
    }
  }

  Map<String, dynamic> _createRoom(String roomId, Map<String, dynamic> config) {
    if (_rooms.containsKey(roomId)) throw Exception('Room exists');
    _rooms[roomId] = _Room(roomId, config);
    return {'status': 'created', 'roomId': roomId};
  }

  Map<String, dynamic> _joinRoom(
      String roomId, String userId, String? password) {
    final room = _rooms[roomId];
    if (room == null) throw Exception('Room not found');
    if (room.hasPassword && room.password != password)
      throw Exception('Wrong password');

    // Возвращаем список тех, кто уже в комнате (чтобы мы им позвонили)
    final existingPeers = room.peers.toList();
    room.peers.add(userId);
    return {'status': 'joined', 'peers': existingPeers};
  }

  void _leaveRoom(String roomId, String userId) {
    final room = _rooms[roomId];
    if (room != null) {
      room.peers.remove(userId);
      if (room.peers.isEmpty) _rooms.remove(roomId);
    }
  }
}

class _Room {
  final String id;
  final Map<String, dynamic> config;
  final Set<String> peers = {};

  _Room(this.id, this.config);
  String? get password => config['password'];
  bool get hasPassword => password != null && password!.isNotEmpty;
}

// ==========================================
// ЧАСТЬ 2: КЛИЕНТСКИЙ SDK (Для Flutter)
// ==========================================

/// Интерфейс, который разработчик должен реализовать, чтобы соединить SDK со своим бэкендом
abstract class VoiceSignalingTransport {
  Future<void> connect();
  Future<dynamic> sendRequest(
      String type, dynamic payload); // REST или Socket вызов
  Stream<VoiceSignalData>
      get incomingSignals; // Стрим входящих сообщений от других юзеров
}

class VoiceSignalData {
  final String fromPeerId;
  final dynamic data;
  VoiceSignalData(this.fromPeerId, this.data);
}

/// Основной класс для управления звонками.
/// Usage: final voice = VoiceClient(transport);
class VoiceClient {
  final VoiceSignalingTransport transport;

  // Состояние
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _connections = {};
  final Map<String, MediaStream> _remoteStreams =
      {}; // Храним стримы для управления громкостью

  // Стримы событий для UI
  final _participantsController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get participantsStream => _participantsController.stream;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  VoiceClient({required this.transport});

  /// 1. Инициализация (запрос прав и подключение к сокету)
  Future<void> init() async {
    await transport.connect();
    transport.incomingSignals.listen(_handleSignal);
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
    } catch (e) {
      _errorController.add("Ошибка микрофона: $e");
    }
  }

  /// 2. Создать комнату
  Future<void> createRoom(String roomId,
      {String? password, int maxPeers = 10}) async {
    await transport.sendRequest('create', {
      'roomId': roomId,
      'config': {'password': password, 'max': maxPeers}
    });
    // После создания сразу входим
    await joinRoom(roomId, password: password);
  }

  /// 3. Войти в комнату
  Future<void> joinRoom(String roomId, {String? password}) async {
    final response = await transport
        .sendRequest('join', {'roomId': roomId, 'password': password});

    // Сервер вернул список тех, кто уже там. Звоним им.
    List<dynamic> peers = response['peers'];
    for (var peerId in peers) {
      await _connectToPeer(peerId as String, initiateOffer: true);
    }
    _updateParticipants();
  }

  /// 4. Выйти
  Future<void> leave(String roomId) async {
    _localStream?.getTracks().forEach((t) => t.stop());
    for (var pc in _connections.values) {
      await pc.close();
    }
    _connections.clear();
    _remoteStreams.clear();
    _updateParticipants();
    await transport.sendRequest('leave', {'roomId': roomId});
  }

  /// 5. Управление своим микрофоном
  void toggleMyMic(bool isEnabled) {
    if (_localStream != null) {
      _localStream!.getAudioTracks()[0].enabled = isEnabled;
    }
  }

  /// 6. Отключить звук конкретного участника (для себя)
  void muteParticipant(String peerId, bool isMuted) {
    final stream = _remoteStreams[peerId];
    if (stream != null && stream.getAudioTracks().isNotEmpty) {
      stream.getAudioTracks()[0].enabled = !isMuted;
    }
  }

  /// 7. Регулировка громкости участника (0.0 - 1.0)
  /// Примечание: В чистом Flutter WebRTC поддержка setVolume зависит от платформы.
  void setParticipantVolume(String peerId, double volume) {
    // Это placeholder. В нативном WebRTC volume обычно ставится на Render'е или через AudioTrack helper.
    // Для простоты реализации здесь мы делаем Mute если volume == 0
    muteParticipant(peerId, volume == 0);
  }

  // --- PRIVATE LOGIC ---

  Future<void> _connectToPeer(String peerId,
      {bool initiateOffer = false}) async {
    final pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'}
      ]
    });
    _connections[peerId] = pc;

    // Отправка наших аудио данных
    if (_localStream != null) {
      _localStream!
          .getTracks()
          .forEach((track) => pc.addTrack(track, _localStream!));
    }

    // Получение аудио данных собеседника
    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteStreams[peerId] = event.streams[0];
      }
    };

    pc.onIceCandidate = (candidate) {
      transport.sendRequest('signal', {
        'to': peerId,
        'data': {
          'type': 'candidate',
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'line': candidate.sdpMLineIndex
          }
        }
      });
    };

    if (initiateOffer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _sendSignal(peerId, 'offer', offer.sdp!);
    }
  }

  Future<void> _handleSignal(VoiceSignalData signal) async {
    var pc = _connections[signal.fromPeerId];
    final payload = signal.data;
    final type = payload['type'];

    if (pc == null && type == 'offer') {
      await _connectToPeer(signal.fromPeerId, initiateOffer: false);
      pc = _connections[signal.fromPeerId];
      _updateParticipants();
    }

    if (pc == null) return;

    if (type == 'offer') {
      await pc
          .setRemoteDescription(RTCSessionDescription(payload['sdp'], 'offer'));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignal(signal.fromPeerId, 'answer', answer.sdp!);
    } else if (type == 'answer') {
      await pc.setRemoteDescription(
          RTCSessionDescription(payload['sdp'], 'answer'));
    } else if (type == 'candidate') {
      final cand = payload['candidate'];
      await pc.addCandidate(
          RTCIceCandidate(cand['candidate'], cand['sdpMid'], cand['line']));
    }
  }

  void _sendSignal(String to, String type, String sdp) {
    transport.sendRequest('signal', {
      'to': to,
      'data': {'type': type, 'sdp': sdp}
    });
  }

  void _updateParticipants() {
    _participantsController.add(_connections.keys.toList());
  }
}
