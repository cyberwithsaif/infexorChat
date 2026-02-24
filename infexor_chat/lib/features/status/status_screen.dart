import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/url_utils.dart';
import '../auth/providers/auth_provider.dart';
import 'status_provider.dart';
import 'create_status_screen.dart';
import 'view_status_screen.dart';

class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(statusProvider.notifier).loadStatuses();
      ref.read(statusProvider.notifier).initSocketListeners();
    });
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return DateFormat('dd/MM/yy').format(date);
    } catch (_) {
      return '';
    }
  }

  void _openCreateText() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateStatusScreen(imageMode: false),
      ),
    );
    if (result == true) {
      ref.read(statusProvider.notifier).loadStatuses();
    }
  }

  void _openCreateImage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateStatusScreen(imageMode: true),
      ),
    );
    if (result == true) {
      ref.read(statusProvider.notifier).loadStatuses();
    }
  }

  void _viewMyStatuses(List<Map<String, dynamic>> statuses) {
    final user = ref.read(authProvider).user ?? {};
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewStatusScreen(user: user, statuses: statuses),
      ),
    );
  }

  void _viewContactStatuses(Map<String, dynamic> group) {
    final user = group['user'];
    final statuses = <Map<String, dynamic>>[];
    final rawStatuses = group['statuses'];
    if (rawStatuses is List) {
      for (final s in rawStatuses) {
        if (s is Map) statuses.add(Map<String, dynamic>.from(s));
      }
    }
    if (statuses.isEmpty || user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ViewStatusScreen(
          user: user is Map ? Map<String, dynamic>.from(user) : {},
          statuses: statuses,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusState = ref.watch(statusProvider);
    final currentUser = ref.watch(authProvider).user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    final avatar = UrlUtils.getFullUrl(currentUser?['avatar'] ?? '');
    final hasMyStatus = statusState.myStatuses.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Status',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryPurple,
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: (value) {
              if (value == 'text') _openCreateText();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'text', child: Text('Text status')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(statusProvider.notifier).loadStatuses(),
        child: ListView(
          children: [
            // ─── My Status Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'My Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subtitleColor,
                ),
              ),
            ),

            // ─── My Status Item ───
            InkWell(
              onTap: hasMyStatus
                  ? () => _viewMyStatuses(statusState.myStatuses)
                  : _openCreateText,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        _StatusRing(
                          avatarUrl: avatar,
                          hasStatus: hasMyStatus,
                          isSeen: true,
                          radius: 28,
                        ),
                        if (!hasMyStatus)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                shape: BoxShape.circle,
                                border: Border.all(color: bgColor, width: 2),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasMyStatus
                                ? _formatTime(
                                    statusState.myStatuses.first['createdAt']
                                        ?.toString(),
                                  )
                                : 'Tap to add status update',
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasMyStatus)
                      Text(
                        '${statusState.myStatuses.length}',
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ─── Recent updates ───
            if (statusState.contactStatuses.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Text(
                  'Recent Updates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 20,
                  alignment: WrapAlignment.start,
                  children: statusState.contactStatuses.map((group) {
                    final user = group['user'];
                    final name = user is Map
                        ? (user['name'] ?? 'Unknown')
                              .toString()
                              .split(' ')
                              .first
                        : 'Unknown';
                    final userAvatar = user is Map
                        ? UrlUtils.getFullUrl(user['avatar'] ?? '')
                        : '';
                    final hasUnviewed = group['hasUnviewed'] == true;

                    return InkWell(
                      onTap: () => _viewContactStatuses(group),
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 76, // Fixed width to align grid perfectly
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StatusRing(
                              avatarUrl: userAvatar,
                              hasStatus: true,
                              isSeen: !hasUnviewed,
                              radius: 34, // Slightly larger radius for grid
                            ),
                            const SizedBox(height: 8),
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],

            // ─── Empty state ───
            if (statusState.contactStatuses.isEmpty &&
                !statusState.isLoading) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Recent updates',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.circle_outlined,
                        size: 56,
                        color: subtitleColor.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No recent updates',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Status updates from your contacts\nwill appear here',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: subtitleColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            if (statusState.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'text_status',
            onPressed: _openCreateText,
            backgroundColor: isDark
                ? AppColors.darkBgSecondary
                : AppColors.bgCard,
            child: Icon(Icons.edit, color: textColor, size: 20),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'camera_status',
            onPressed: _openCreateImage,
            backgroundColor: AppColors.fabBg,
            foregroundColor: Colors.white,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }
}

/// Widget that shows an avatar with a segmented ring around it
class _StatusRing extends StatelessWidget {
  final String avatarUrl;
  final bool hasStatus;
  final bool isSeen;
  final double radius;

  const _StatusRing({
    required this.avatarUrl,
    required this.hasStatus,
    required this.isSeen,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = hasStatus
        ? (isSeen
              ? Colors.grey.withValues(alpha: 0.3)
              : AppColors.primaryPurple)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: hasStatus ? Border.all(color: ringColor, width: 2.5) : null,
      ),
      child: CircleAvatar(
        radius: radius - 2.5,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkBgSecondary
            : AppColors.bgCard,
        backgroundImage: avatarUrl.isNotEmpty
            ? CachedNetworkImageProvider(avatarUrl)
            : null,
        child: avatarUrl.isEmpty
            ? Icon(Icons.person, size: radius * 0.7, color: Colors.grey)
            : null,
      ),
    );
  }
}
