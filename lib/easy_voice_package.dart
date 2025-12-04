import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

// ====================================================================
// !!! ВНИМАНИЕ: ЭТОТ КОД ПРЕДСТАВЛЯЕТ СОБОЙ ВНУТРЕННЮЮ, СКРЫТУЮ ЛОГИКУ !!!
// !!! РЕАЛЬНОГО SDK. РАЗРАБОТЧИК НЕ КОПИРУЕТ ЭТОТ ФАЙЛ, А ИСПОЛЬЗУЕТ !!!
// !!! ТОЛЬКО ЕГО ПУБЛИЧНЫЕ ИНТЕРФЕЙСЫ (VoiceClient и VoiceSignalingTransport).
// ====================================================================

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
        return _createRoom(payload['roomId'], payload['config'], userId);
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

  Map<String, dynamic> _createRoom(
      String roomId, Map<String, dynamic> config, String userId) {
    if (_rooms.containsKey(roomId)) throw Exception('Room exists');
    _rooms[roomId] = _Room(roomId, config);
    // Добавляем создателя комнаты
    _rooms[roomId]!.peers.add(userId);
    return {
      'status': 'created',
      'roomId': roomId,
      'peers': [userId]
    };
  }

  Map<String, dynamic> _joinRoom(
      String roomId, String userId, String? password) {
    final room = _rooms[roomId];
    if (room == null) throw Exception('Room not found');
    if (room.hasPassword && room.password != password)
      throw Exception('Wrong password');

    // Возвращаем список тех, кто уже в комнате (чтобы мы им позвонили)
    final existingPeers = room.peers.toList();
    if (!room.peers.contains(userId)) {
      room.peers.add(userId);
    }
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
  String? _currentRoomId;
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
    try {
      await transport.sendRequest('create', {
        'roomId': roomId,
        'config': {'password': password, 'max': maxPeers}
      });
      _currentRoomId = roomId;
      // После создания сразу входим
      await joinRoom(roomId, password: password);
    } catch (e) {
      _errorController.add("Ошибка создания комнаты: $e");
    }
  }

  /// 3. Войти в комнату
  Future<void> joinRoom(String roomId, {String? password}) async {
    try {
      final response = await transport
          .sendRequest('join', {'roomId': roomId, 'password': password});
      _currentRoomId = roomId;

      // Сервер вернул список тех, кто уже там. Звоним им.
      List<dynamic> peers = response['peers'];
      for (var peerId in peers) {
        // Мы уже в комнате, подключаемся к существующим
        await _connectToPeer(peerId as String, initiateOffer: true);
      }
      _updateParticipants();
    } catch (e) {
      _errorController.add("Ошибка присоединения к комнате: $e");
    }
  }

  /// 4. Выйти
  Future<void> leave() async {
    if (_currentRoomId == null) return;

    _localStream?.getTracks().forEach((t) => t.stop());
    for (var pc in _connections.values) {
      await pc.close();
    }
    _connections.clear();
    _remoteStreams.clear();

    await transport.sendRequest('leave', {'roomId': _currentRoomId});
    _currentRoomId = null;
    _updateParticipants();
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
      // isMuted = true -> enabled = false
      stream.getAudioTracks()[0].enabled = !isMuted;
    }
  }

  /// 7. Регулировка громкости участника (0.0 - 1.0)
  /// Примечание: В чистом Flutter WebRTC поддержка setVolume зависит от платформы.
  void setParticipantVolume(String peerId, double volume) {
    // В реальном SDK здесь будет вызов нативного API для установки громкости.
    // Для простоты реализации здесь мы используем mute при volume == 0
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
        // TODO: Здесь нужен механизм, который передаст MediaStream в UI для рендера (AudioElement)
      }
    };

    // Обработка отключения пира
    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _connections.remove(peerId);
        _remoteStreams.remove(peerId);
        _updateParticipants();
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

    _updateParticipants();
  }

  Future<void> _handleSignal(VoiceSignalData signal) async {
    var pc = _connections[signal.fromPeerId];
    final payload = signal.data;
    final type = payload['type'];

    // Если получили offer от пира, которого еще нет в _connections, то создаем его.
    if (pc == null && type == 'offer') {
      await _connectToPeer(signal.fromPeerId, initiateOffer: false);
      pc = _connections[signal.fromPeerId];
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
    // В список добавляем только тех, кто реально подключен (есть в _connections)
    _participantsController.add(_connections.keys.toList());
  }
}
