/// WebRTC сигнал для передачи между клиентами
class WebRtcSignal {
  /// Тип сигнала: 'webrtc_offer', 'webrtc_answer', 'webrtc_ice_candidate', 'leave_room'
  final String type;

  /// JSON payload с данными сигнала (SDP, ICE candidate и т.д.)
  final String payload;

  /// SessionId отправителя
  final String senderSessionId;

  WebRtcSignal({
    required this.type,
    required this.payload,
    required this.senderSessionId,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'payload': payload,
        'senderSessionId': senderSessionId,
      };

  factory WebRtcSignal.fromJson(Map<String, dynamic> json) => WebRtcSignal(
        type: json['type'] as String,
        payload: json['payload'] as String,
        senderSessionId: json['senderSessionId'] as String,
      );
}
