import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/call_history_provider.dart';
import '../providers/chat_provider.dart';
import '../models/call_log.dart';
import 'call_screen.dart';

class CallsScreen extends ConsumerWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final callHistoryState = ref.watch(callHistoryProvider);
    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?['_id']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calls'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: callHistoryState.when(
        loading: () => const SizedBox.shrink(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text('Failed to load call history'),
              TextButton(
                onPressed: () =>
                    ref.read(callHistoryProvider.notifier).fetchCallHistory(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (calls) {
          if (calls.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(callHistoryProvider.notifier).fetchCallHistory();
            },
            child: ListView.builder(
              itemCount: calls.length,
              itemBuilder: (context, index) {
                final callLog = calls[index];
                return _CallTile(
                  callLog: callLog,
                  currentUserId: currentUserId,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Open contact selection to make a call
        },
        backgroundColor: const Color(0xFFFF6B6B),
        child: const Icon(Icons.add_call, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_missed,
            size: 80,
            color: isDark ? Colors.white54 : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'No recent calls',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white54 : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _CallTile extends ConsumerWidget {
  final CallLog callLog;
  final String currentUserId;

  const _CallTile({required this.callLog, required this.currentUserId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOutgoing = callLog.callerId == currentUserId;
    final otherUser = isOutgoing ? callLog.receiver : callLog.caller;

    // Fallbacks if user details not populated
    final displayName =
        otherUser?['name']?.toString() ??
        'Unknown Caller'; // Changed to map access
    final avatarPath =
        otherUser?['avatar']?.toString() ?? ''; // Changed to map access
    final avatarUrl = UrlUtils.getFullUrl(avatarPath);

    // Date formatting
    final timeStr = DateFormat('h:mm a').format(callLog.timestamp);
    final isToday = DateTime.now().difference(callLog.timestamp).inDays == 0;
    final dateStr = isToday
        ? 'Today, $timeStr'
        : DateFormat('MMM d, h:mm a').format(callLog.timestamp);

    // Call icon style
    IconData statusIcon = Icons.call_made;
    Color statusColor = Colors.green;

    if (callLog.status == 'missed') {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
      statusColor = Colors.red;
    } else if (callLog.status == 'declined') {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_missed;
      statusColor = Colors.red;
    } else {
      statusIcon = isOutgoing ? Icons.call_made : Icons.call_received;
      statusColor = Colors.green;
    }

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.accentBlue.withValues(alpha: 0.1),
        backgroundImage: avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.accentBlue,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: callLog.status == 'missed' && !isOutgoing ? Colors.red : null,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 16),
          const SizedBox(width: 4),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          if (callLog.status == 'completed' && callLog.duration > 0) ...[
            const SizedBox(width: 6),
            Text(
              "• ${_formatDuration(callLog.duration)}",
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          callLog.type == 'video' ? Icons.videocam : Icons.call,
          color: const Color(0xFFFF6B6B),
        ),
        onPressed: () {
          // Trigger a new call back to this user
          final otherUserId = isOutgoing
              ? callLog.receiverId
              : callLog.callerId;

          // Find if we have an existing chat with this user
          final chatListState = ref.read(chatListProvider);
          String chatId = '';
          for (final chat in chatListState.chats) {
            final participants = chat['participants'] as List?;
            if (participants != null &&
                participants.any((p) => p is Map && p['_id'] == otherUserId)) {
              chatId = chat['_id'];
              break;
            }
          }

          if (chatId.isEmpty) {
            // Generate a temporary chat ID for the call if one does not exist
            chatId = 'temp_${currentUserId}_$otherUserId';
          }

          Navigator.push(
            context,
            ScaleFadePageRoute(
              builder: (_) => CallPage(
                chatId: chatId,
                userId: otherUserId,
                callerName: displayName,
                callerAvatar: avatarPath,
                isVideoCall: callLog.type == 'video',
                isIncoming: false,
              ),
            ),
          );
        },
      ),
      onTap: () {
        // Can open a detail sheet or page
      },
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final minutes = seconds ~/ 60;
    return '$minutes min';
  }
}
