import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_call_provider.dart';
import '../../config/routes.dart';

/// A slim green banner that shows at the top of the app when a call is active.
/// Tapping it returns to the call screen using GoRouter.
class ActiveCallBanner extends ConsumerWidget {
  const ActiveCallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(activeCallProvider);

    if (!callState.isActive) return const SizedBox.shrink();

    final isRinging = callState.status == 'ringing';
    final duration = ref
        .read(activeCallProvider.notifier)
        .formatDuration(callState.duration);

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: () {
          // Clear banner state
          ref.read(activeCallProvider.notifier).clearActiveCall();

          if (isRinging && callState.isIncoming) {
            // Return to incoming call screen
            router.push(
              '/incoming-call',
              extra: {
                'callId': 'call_${callState.chatId}',
                'chatId': callState.chatId,
                'callerId': callState.userId,
                'callerName': callState.callerName,
                'callerAvatar': callState.callerAvatar,
                'isVideo': callState.isVideoCall,
              },
            );
          } else {
            // Navigate back to call screen via GoRouter
            router.push(
              '/call',
              extra: {
                'chatId': callState.chatId,
                'userId': callState.userId,
                'callerName': callState.callerName,
                'callerAvatar': callState.callerAvatar,
                'isVideoCall': callState.isVideoCall,
                'isIncoming': callState.isIncoming,
                'isResuming': true,
                'initialDuration': callState.duration,
              },
            );
          }
        },
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top,
            bottom: 8,
            left: 16,
            right: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF00A884), // WhatsApp Green
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _BlinkingIcon(
                icon: callState.isVideoCall
                    ? Icons.videocam
                    : Icons.phone_in_talk,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isRinging ? 'Ringing...' : 'Ongoing Call',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isRinging
                          ? 'Tap to return'
                          : '${callState.callerName} • $duration',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white70,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlinkingIcon extends StatefulWidget {
  final IconData icon;
  const _BlinkingIcon({required this.icon});

  @override
  State<_BlinkingIcon> createState() => _BlinkingIconState();
}

class _BlinkingIconState extends State<_BlinkingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Icon(widget.icon, color: Colors.white, size: 20),
    );
  }
}
