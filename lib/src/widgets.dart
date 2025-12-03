/// Ready-to-use UI widgets for WebRTC applications.
/// Use as-is or customize by extending/copying the code.

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'webrtc_controller.dart';

// ============================================================================
// Peer Grid View Widget
// ============================================================================

/// Ready-to-use widget to display connected peers in a grid.
///
/// Usage (basic):
/// ```dart
/// WebRTCPeerGridView(
///   controller: manager.controller,
/// )
/// ```
///
/// Usage (custom):
/// ```dart
/// WebRTCPeerGridView(
///   controller: manager.controller,
///   crossAxisCount: 3,
///   peerBuilder: (context, peerId, renderer) {
///     return CustomPeerCard(peerId: peerId, renderer: renderer);
///   },
/// )
/// ```
class WebRTCPeerGridView extends StatelessWidget {
  final WebRTCController controller;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final Widget Function(BuildContext, String, RTCVideoRenderer?)? peerBuilder;

  const WebRTCPeerGridView({
    Key? key,
    required this.controller,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 8,
    this.mainAxisSpacing = 8,
    this.peerBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: crossAxisSpacing,
        mainAxisSpacing: mainAxisSpacing,
      ),
      itemCount: controller.connectedPeers.length,
      itemBuilder: (context, index) {
        final peerId = controller.connectedPeers[index];
        final renderer = controller.getRemoteRenderer(peerId);

        return peerBuilder?.call(context, peerId, renderer) ??
            _DefaultPeerCard(peerId: peerId, renderer: renderer);
      },
    );
  }
}

/// Default peer card widget
class _DefaultPeerCard extends StatelessWidget {
  final String peerId;
  final RTCVideoRenderer? renderer;

  const _DefaultPeerCard({
    required this.peerId,
    required this.renderer,
  });

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
                  Icon(Icons.person, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    peerId.substring(
                        0, (peerId.length < 8 ? peerId.length : 8)),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================================================
// Connection Status Widget
// ============================================================================

/// Ready-to-use connection status indicator.
///
/// Usage (basic):
/// ```dart
/// WebRTCConnectionStatus(controller: manager.controller)
/// ```
///
/// Usage (custom colors):
/// ```dart
/// WebRTCConnectionStatus(
///   controller: manager.controller,
///   connectedColor: Colors.green,
///   connectingColor: Colors.orange,
///   failedColor: Colors.red,
/// )
/// ```
class WebRTCConnectionStatus extends StatelessWidget {
  final WebRTCController controller;
  final Color connectedColor;
  final Color connectingColor;
  final Color failedColor;
  final Color disconnectedColor;

  const WebRTCConnectionStatus({
    Key? key,
    required this.controller,
    this.connectedColor = Colors.green,
    this.connectingColor = Colors.orange,
    this.failedColor = Colors.red,
    this.disconnectedColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final color = _getColorForState(controller.callState);
        final text = controller.callState.toString().split('.').last;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
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
      },
    );
  }

  Color _getColorForState(dynamic state) {
    final stateStr = state.toString();
    if (stateStr.contains('connected')) return connectedColor;
    if (stateStr.contains('connecting')) return connectingColor;
    if (stateStr.contains('failed')) return failedColor;
    return disconnectedColor;
  }
}

// ============================================================================
// Control Panel Widget
// ============================================================================

/// Ready-to-use control panel with mute and volume buttons.
///
/// Usage (basic):
/// ```dart
/// WebRTCControlPanel(controller: manager.controller)
/// ```
///
/// Usage (custom actions):
/// ```dart
/// WebRTCControlPanel(
///   controller: manager.controller,
///   onLeavePressed: () => Navigator.pop(context),
///   showVolumeSlider: true,
/// )
/// ```
class WebRTCControlPanel extends StatefulWidget {
  final WebRTCController controller;
  final VoidCallback? onLeavePressed;
  final bool showVolumeSlider;
  final Color muteColor;
  final Color leaveColor;

  const WebRTCControlPanel({
    Key? key,
    required this.controller,
    this.onLeavePressed,
    this.showVolumeSlider = true,
    this.muteColor = Colors.green,
    this.leaveColor = Colors.red,
  }) : super(key: key);

  @override
  State<WebRTCControlPanel> createState() => _WebRTCControlPanelState();
}

class _WebRTCControlPanelState extends State<WebRTCControlPanel> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        return Column(
          children: [
            // Control buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute button
                FloatingActionButton(
                  onPressed: () {
                    widget.controller
                        .toggleMute(!widget.controller.isLocalMuted);
                  },
                  backgroundColor: widget.controller.isLocalMuted
                      ? Colors.red
                      : widget.muteColor,
                  child: Icon(
                    widget.controller.isLocalMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),

                // Leave button
                FloatingActionButton(
                  onPressed: () async {
                    await widget.controller.leaveRoom();
                    if (mounted && widget.onLeavePressed != null) {
                      widget.onLeavePressed!();
                    }
                  },
                  backgroundColor: widget.leaveColor,
                  child: const Icon(Icons.call_end, color: Colors.white),
                ),
              ],
            ),

            // Volume slider
            if (widget.showVolumeSlider) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Volume: ${(widget.controller.remoteVolume * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Slider(
                      value: widget.controller.remoteVolume,
                      onChanged: (value) =>
                          widget.controller.setRemoteVolume(value),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ============================================================================
// Empty Peers Widget
// ============================================================================

/// Widget displayed when no peers are connected.
class WebRTCEmptyPeersPlaceholder extends StatelessWidget {
  final String message;
  final IconData icon;
  final Color iconColor;

  const WebRTCEmptyPeersPlaceholder({
    Key? key,
    this.message = 'No participants connected',
    this.icon = Icons.people,
    this.iconColor = Colors.grey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
