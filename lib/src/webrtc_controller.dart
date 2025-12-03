import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'models/call_connection_state.dart';
import 'models/peer_connection_data.dart';
import 'models/webrtc_signal.dart';
import 'signaling/signaling_interface.dart';

/// Основной контроллер для управления WebRTC соединениями
/// Поддерживает mesh топологию (один RTCPeerConnection на каждого пира)
class WebRTCController extends ChangeNotifier {
  final SignalingInterface signalingInterface;
  final String localSessionId;
  final Map<String, dynamic> iceConfiguration;

  // Private state
  late MediaStream _localStream;
  final Map<String, PeerConnectionData> _peerConnections = {};
  StreamSubscription? _signalSubscription;

  CallConnectionState _callState = CallConnectionState.disconnected;
  bool _isLocalMuted = false;
  double _remoteVolume = 1.0;

  // Getters
  CallConnectionState get callState => _callState;
  bool get isLocalMuted => _isLocalMuted;
  double get remoteVolume => _remoteVolume;
  List<String> get connectedPeers => _peerConnections.keys.toList();

  /// Конструктор
  WebRTCController({
    required this.signalingInterface,
    required this.localSessionId,
    Map<String, dynamic>? iceConfiguration,
  }) : iceConfiguration = iceConfiguration ??
            {
              'iceServers': [
                {'urls': 'stun:stun.l.google.com:19302'},
                {'urls': 'stun:stun1.l.google.com:19302'},
              ],
            };

  /// Инициализация контроллера для конкретной комнаты
  Future<void> initialize(String roomId) async {
    try {
      // Инициализация сигналинга
      await signalingInterface.initialize(roomId);

      // Получение локального медиа потока
      await _setupLocalStream();

      // Слушание входящих сигналов
      _listenToSignals();

      _updateCallState(CallConnectionState.connected);
      notifyListeners();
    } catch (e) {
      _updateCallState(CallConnectionState.failed);
      notifyListeners();
      rethrow;
    }
  }

  /// Получение локального медиа потока (микрофон/камера)
  Future<void> _setupLocalStream() async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
  }

  /// Переключение мута микрофона
  void toggleMute(bool isMuted) {
    _isLocalMuted = isMuted;
    _localStream.getAudioTracks().forEach((track) {
      track.enabled = !_isLocalMuted;
    });
    notifyListeners();
  }

  /// Установка громкости удаленных участников
  Future<void> setRemoteVolume(double volume) async {
    _remoteVolume = volume.clamp(0.0, 1.0);
    // Note: flutter_webrtc RTCVideoRenderer не имеет встроенного setVolume
    // Это должно быть реализовано на уровне платформы или через RTCRtpReceiver
    notifyListeners();
  }

  // ============================================================================
  // Управление P2P соединениями
  // ============================================================================

  /// Создание предложений (offers) для новых пиров
  Future<void> createOffersForPeers(List<String> peerIds) async {
    for (String peerId in peerIds) {
      if (!_peerConnections.containsKey(peerId)) {
        await _createPeerConnection(peerId, isOfferer: true);
      }
    }
  }

  /// Создание одного P2P соединения
  Future<void> _createPeerConnection(
    String peerId, {
    bool isOfferer = false,
  }) async {
    try {
      final pc = await createPeerConnection(iceConfiguration);
      final renderer = RTCVideoRenderer();
      await renderer.initialize();

      // Добавление локальных треков
      for (var track in _localStream.getTracks()) {
        pc.addTrack(track, _localStream);
      }

      // Обработка ICE кандидатов
      pc.onIceCandidate = (candidate) async {
        await _sendSignal(
          type: 'webrtc_ice_candidate',
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
          targetPeerId: peerId,
        );
      };

      // Обработка удаленных аудио треков
      pc.onTrack = (RTCTrackEvent event) {
        Future.microtask(() async {
          try {
            MediaStream stream;
            if (event.streams.isNotEmpty) {
              stream = event.streams[0];
            } else {
              stream = await createLocalMediaStream('remote-$peerId');
              try {
                stream.addTrack(event.track);
              } catch (_) {
                // Some platforms may not support addTrack on created stream
              }
            }
            renderer.srcObject = stream;
            notifyListeners();
          } catch (e) {
            // Silently handle track setup errors
          }
        });
      };

      // Обработка изменений состояния соединения
      pc.onConnectionState = (state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _updateCallState(CallConnectionState.connected);
        } else if (state ==
                RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
          if (_peerConnections.isEmpty) {
            _updateCallState(CallConnectionState.disconnected);
          }
        }
      };

      _peerConnections[peerId] = PeerConnectionData(
        peerConnection: pc,
        renderer: renderer,
        peerId: peerId,
        isOfferer: isOfferer,
      );

      if (isOfferer) {
        await _createAndSendOffer(peerId, pc);
      }
    } catch (e) {
      // Handle connection creation error silently
    }
  }

  /// Создание и отправка SDP offer
  Future<void> _createAndSendOffer(
    String peerId,
    RTCPeerConnection pc,
  ) async {
    try {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);

      await _sendSignal(
        type: 'webrtc_offer',
        payload: offer.toMap(),
        targetPeerId: peerId,
      );
    } catch (e) {
      // Handle offer creation error silently
    }
  }

  /// Обработка полученного offer от пира
  Future<void> _handleOfferReceived(
    Map<String, dynamic> offerMap,
    String peerId,
  ) async {
    try {
      if (!_peerConnections.containsKey(peerId)) {
        await _createPeerConnection(peerId, isOfferer: false);
      }

      final pc = _peerConnections[peerId]!.peerConnection;
      final offer = RTCSessionDescription(offerMap['sdp'], offerMap['type']);

      await pc.setRemoteDescription(offer);

      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);

      await _sendSignal(
        type: 'webrtc_answer',
        payload: answer.toMap(),
        targetPeerId: peerId,
      );
    } catch (e) {
      // Handle offer error silently
    }
  }

  /// Обработка полученного answer от пира
  Future<void> _handleAnswerReceived(
    Map<String, dynamic> answerMap,
    String peerId,
  ) async {
    try {
      if (!_peerConnections.containsKey(peerId)) return;

      final pc = _peerConnections[peerId]!.peerConnection;
      final answer = RTCSessionDescription(
        answerMap['sdp'],
        answerMap['type'],
      );
      await pc.setRemoteDescription(answer);
    } catch (e) {
      // Handle answer error silently
    }
  }

  /// Обработка полученного ICE кандидата
  Future<void> _handleCandidateReceived(
    Map<String, dynamic> candidateMap,
    String peerId,
  ) async {
    try {
      if (!_peerConnections.containsKey(peerId)) return;

      final pc = _peerConnections[peerId]!.peerConnection;
      final candidate = RTCIceCandidate(
        candidateMap['candidate'],
        candidateMap['sdpMid'],
        candidateMap['sdpMLineIndex'],
      );

      await pc.addCandidate(candidate);
    } catch (e) {
      // Handle candidate error silently
    }
  }

  // ============================================================================
  // Сигналинг
  // ============================================================================

  /// Отправка сигнала на сервер
  Future<void> _sendSignal({
    required String type,
    required Map<String, dynamic> payload,
    String? targetPeerId,
  }) async {
    final signal = WebRtcSignal(
      type: type,
      payload: jsonEncode({
        ...payload,
        if (targetPeerId != null) 'targetPeerId': targetPeerId,
      }),
      senderSessionId: localSessionId,
    );

    try {
      await signalingInterface.sendSignal(signal);
    } catch (e) {
      rethrow;
    }
  }

  /// Слушание входящих сигналов
  void _listenToSignals() {
    _signalSubscription?.cancel();

    _signalSubscription = signalingInterface.getSignalStream().listen(
      (WebRtcSignal signal) async {
        // Не обрабатываем свои собственные сигналы
        if (signal.senderSessionId == localSessionId) return;

        final payload = jsonDecode(signal.payload);
        final peerId = signal.senderSessionId;

        // Если сигнал направлен конкретному пиру, проверяем target
        if (payload is Map && payload.containsKey('targetPeerId')) {
          final target = payload['targetPeerId'];
          if (target != null && target != localSessionId) return;
        }

        // Диспетчеризация сигнала по типу
        switch (signal.type) {
          case 'webrtc_offer':
            await _handleOfferReceived(payload, peerId);
            break;

          case 'webrtc_answer':
            await _handleAnswerReceived(payload, peerId);
            break;

          case 'webrtc_ice_candidate':
            await _handleCandidateReceived(payload, peerId);
            break;

          case 'leave_room':
            await cleanUpPeer(peerId);
            break;
        }
      },
      onError: (e) {
        // Handle stream error silently
      },
    );
  }

  // ============================================================================
  // Очистка и завершение
  // ============================================================================

  /// Выход из комнаты и очистка всех ресурсов
  Future<void> leaveRoom() async {
    try {
      await _sendSignal(type: 'leave_room', payload: {});
    } catch (e) {
      // Handle leave signal error silently
    }
    await cleanUpAll();
  }

  /// Очистка соединения с одним пиром
  Future<void> cleanUpPeer(String peerId) async {
    final peerData = _peerConnections.remove(peerId);
    if (peerData != null) {
      if (peerData.peerConnection.iceConnectionState !=
          RTCIceConnectionState.RTCIceConnectionStateClosed) {
        await peerData.peerConnection.close();
      }
      await peerData.renderer.dispose();
    }

    if (_peerConnections.isEmpty) {
      _updateCallState(CallConnectionState.disconnected);
    }

    notifyListeners();
  }

  /// Полная очистка всех соединений и ресурсов
  Future<void> cleanUpAll() async {
    final peerIds = _peerConnections.keys.toList();
    for (String peerId in peerIds) {
      await cleanUpPeer(peerId);
    }

    try {
      await _localStream.dispose();
    } catch (e) {
      // Handle disposal error silently
    }

    await _signalSubscription?.cancel();

    _isLocalMuted = false;
    _remoteVolume = 1.0;

    _updateCallState(CallConnectionState.disconnected);
    notifyListeners();
  }

  /// Получение рендерера для конкретного пира
  RTCVideoRenderer? getRemoteRenderer(String peerId) {
    return _peerConnections[peerId]?.renderer;
  }

  /// Обновление состояния вызова
  void _updateCallState(CallConnectionState newState) {
    if (_callState != newState) {
      _callState = newState;
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    await cleanUpAll();
    super.dispose();
  }
}
