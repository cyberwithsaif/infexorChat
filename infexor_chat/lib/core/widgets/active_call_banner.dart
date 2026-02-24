import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/active_call_provider.dart';
import '../utils/animated_page_route.dart';
import '../../features/chat/screens/call_screen.dart';

/// A green banner that shows at the top of the app when a call is active
/// and has been minimized. Tapping it returns to the call screen.
class ActiveCallBanner extends ConsumerWidget {
  const ActiveCallBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final callState = ref.watch(activeCallProvider);

    if (!callState.isActive) return const SizedBox.shrink();

    final duration = ref
        .read(activeCallProvider.notifier)
        .formatDuration(callState.duration);

    return GestureDetector(
      onTap: () {
        // Clear banner state
        ref.read(activeCallProvider.notifier).clearActiveCall();
        // Navigate back to call screen
        Navigator.of(context).push(
          ScaleFadePageRoute(
            builder: (_) => CallPage(
              chatId: callState.chatId,
              userId: callState.userId,
              callerName: callState.callerName,
              callerAvatar: callState.callerAvatar,
              isVideoCall: callState.isVideoCall,
              isIncoming: callState.isIncoming,
              isResuming: true,
              initialDuration: callState.duration,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          bottom: 8,
          left: 16,
          right: 16,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF00C853),
          boxShadow: [
            BoxShadow(
              color: Color(0x4000C853),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tap to return to call • $duration',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                callState.isVideoCall ? 'Video' : 'Audio',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
