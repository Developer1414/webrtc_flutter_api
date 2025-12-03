/// Example WebRTC UI using webrtc_flutter_api with Provider
/// This shows how to integrate the WebRTCController into a Flutter UI

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webrtc_flutter_api/webrtc_flutter_api.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WebRTC Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const VoiceCallPage(),
    );
  }
}

class VoiceCallPage extends StatefulWidget {
  const VoiceCallPage({Key? key}) : super(key: key);

  @override
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage> {
  late WebRTCController _controller;

  @override
  void initState() {
    super.initState();
    _initializeWebRTC();
  }

  Future<void> _initializeWebRTC() async {
    // Create your signaling implementation
    // final signalingImpl = MySignalingImplementation();

    // For this example, we'll use a mock implementation
    final signalingImpl = _MockSignalingImplementation();

    _controller = WebRTCController(
      signalingInterface: signalingImpl,
      localSessionId: 'user-123', // Should be unique per user/session
    );

    // Initialize for a specific room
    try {
      await _controller.initialize('room-456');

      // In a real app, you would fetch the list of other participants from your backend
      // and create offers for them
      // await _controller.createOffersForPeers(['peer-1', 'peer-2']);
    } catch (e) {
      print('Error initializing WebRTC: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WebRTCController>.value(
      value: _controller,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Voice Call'),
          elevation: 0,
        ),
        body: Consumer<WebRTCController>(
          builder: (context, controller, _) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Connection status
                  _buildConnectionStatus(controller),
                  const SizedBox(height: 16),

                  // Remote participants grid
                  Expanded(
                    child: _buildRemoteParticipants(controller),
                  ),
                  const SizedBox(height: 16),

                  // Controls
                  _buildControls(controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(WebRTCController controller) {
    final color = controller.callState == CallConnectionState.connected
        ? Colors.green
        : Colors.orange;
    final text = controller.callState.toString().split('.').last;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Status: $text',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${controller.connectedPeers.length} participants',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteParticipants(WebRTCController controller) {
    if (controller.connectedPeers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              'No participants connected',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: controller.connectedPeers.length,
      itemBuilder: (context, index) {
        final peerId = controller.connectedPeers[index];
        final renderer = controller.getRemoteRenderer(peerId);

        return _PeerCard(
          peerId: peerId,
          renderer: renderer,
        );
      },
    );
  }

  Widget _buildControls(WebRTCController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Mute button
        FloatingActionButton(
          onPressed: () {
            controller.toggleMute(!controller.isLocalMuted);
          },
          backgroundColor: controller.isLocalMuted ? Colors.red : Colors.green,
          child: Icon(
            controller.isLocalMuted ? Icons.mic_off : Icons.mic,
            color: Colors.white,
          ),
        ),

        // Leave button
        FloatingActionButton(
          onPressed: () async {
            await controller.leaveRoom();
            if (mounted) {
              Navigator.pop(context);
            }
          },
          backgroundColor: Colors.red,
          child: const Icon(Icons.call_end, color: Colors.white),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _PeerCard extends StatelessWidget {
  final String peerId;
  final RTCVideoRenderer? renderer;

  const _PeerCard({
    Key? key,
    required this.peerId,
    required this.renderer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: renderer != null
          ? RTCVideoView(renderer!)
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    peerId.substring(0, 8),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Mock implementation for demonstration
class _MockSignalingImplementation implements SignalingInterface {
  late StreamController<WebRtcSignal> _controller;

  @override
  Future<void> initialize(String roomId) async {
    _controller = StreamController<WebRtcSignal>.broadcast();
    // In a real implementation, connect to your backend here
  }

  @override
  Future<void> sendSignal(WebRtcSignal signal) async {
    // In a real implementation, send to your backend
    print('Sending signal: ${signal.type}');
  }

  @override
  Stream<WebRtcSignal> getSignalStream() {
    return _controller.stream;
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
