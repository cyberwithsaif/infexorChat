import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../providers/active_call_provider.dart';
import '../services/webrtc_service.dart';
import '../../config/routes.dart';

/// A floating Picture-in-Picture (PiP) widget that shows the remote video stream
/// when a video call is minimized. It can be dragged around the screen.
class ActiveCallPip extends ConsumerStatefulWidget {
  const ActiveCallPip({super.key});

  @override
  ConsumerState<ActiveCallPip> createState() => _ActiveCallPipState();
}

class _ActiveCallPipState extends ConsumerState<ActiveCallPip> {
  // Initial position (right side, a bit below the top banner)
  Offset _position = const Offset(2000, 100);
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final callState = ref.watch(activeCallProvider);

    // Only show PiP if call is active AND it's a video call
    if (!callState.isActive || !callState.isVideoCall) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;

    // Set initial position once based on screen size (top right)
    if (!_initialized) {
      _position = Offset(size.width - 130, paddingTop + 60);
      _initialized = true;
    }

    // Access the singleton WebRTC service to get the remote renderer
    final remoteRenderer = WebRTCService().remoteRenderer;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
            // Constrain widget to screen bounds
            _position = Offset(
              _position.dx.clamp(8.0, size.width - 118.0),
              _position.dy.clamp(paddingTop + 50.0, size.height - 180.0),
            );
          });
        },
        onTap: () {
          // Restore the call screen
          ref.read(activeCallProvider.notifier).clearActiveCall();
          router.push('/call', extra: {
            'chatId': callState.chatId,
            'userId': callState.userId,
            'callerName': callState.callerName,
            'callerAvatar': callState.callerAvatar,
            'isVideoCall': callState.isVideoCall,
            'isIncoming': callState.isIncoming,
            'isResuming': true,
            'initialDuration': callState.duration,
          });
        },
        child: Container(
          width: 110,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              children: [
                RTCVideoView(
                  remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: false,
                ),
                // Tap hint icon
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
