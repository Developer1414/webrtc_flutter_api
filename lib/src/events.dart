/// Easy event listening for WebRTC state changes.
/// Provides streams for all important events without boilerplate.

import 'dart:async';
import 'models/call_connection_state.dart';
import 'webrtc_controller.dart';

/// WebRTC events wrapper for easy listening to state changes.
///
/// Usage:
/// ```dart
/// final events = WebRTCEvents(manager.controller);
///
/// // Listen to connected peers
/// events.onPeersChanged.listen((peers) {
///   print('Connected peers: $peers');
/// });
///
/// // Listen to connection state changes
/// events.onConnectionStateChanged.listen((state) {
///   print('Connection state: $state');
/// });
///
/// // Listen to mute state changes
/// events.onMuteStateChanged.listen((isMuted) {
///   print('Muted: $isMuted');
/// });
/// ```
class WebRTCEvents {
  final WebRTCController _controller;

  // Streams for different events
  late final StreamController<List<String>> _peersChangedController;
  late final StreamController<CallConnectionState> _connectionStateController;
  late final StreamController<bool> _muteStateController;

  /// Stream of connected peers list
  late final Stream<List<String>> onPeersChanged;

  /// Stream of connection state changes
  late final Stream<CallConnectionState> onConnectionStateChanged;

  /// Stream of local mute state changes
  late final Stream<bool> onMuteStateChanged;

  // Track previous state
  late List<String> _previousPeers;
  late CallConnectionState _previousState;
  late bool _previousMuted;

  WebRTCEvents(this._controller) {
    _initializeStreams();
    _previousPeers = _controller.connectedPeers;
    _previousState = _controller.callState;
    _previousMuted = _controller.isLocalMuted;
    _setupListeners();
  }

  void _initializeStreams() {
    _peersChangedController = StreamController<List<String>>.broadcast();
    _connectionStateController =
        StreamController<CallConnectionState>.broadcast();
    _muteStateController = StreamController<bool>.broadcast();

    onPeersChanged = _peersChangedController.stream;
    onConnectionStateChanged = _connectionStateController.stream;
    onMuteStateChanged = _muteStateController.stream;
  }

  void _setupListeners() {
    _controller.addListener(() {
      // Check for peer changes
      final currentPeers = _controller.connectedPeers;
      if (_previousPeers.length != currentPeers.length ||
          !_previousPeers.toSet().containsAll(currentPeers)) {
        _previousPeers = currentPeers;
        _peersChangedController.add(currentPeers);
      }

      // Check for connection state changes
      if (_previousState != _controller.callState) {
        _previousState = _controller.callState;
        _connectionStateController.add(_previousState);
      }

      // Check for mute state changes
      if (_previousMuted != _controller.isLocalMuted) {
        _previousMuted = _controller.isLocalMuted;
        _muteStateController.add(_previousMuted);
      }
    });
  }

  /// Dispose all streams
  void dispose() {
    _peersChangedController.close();
    _connectionStateController.close();
    _muteStateController.close();
  }
}
