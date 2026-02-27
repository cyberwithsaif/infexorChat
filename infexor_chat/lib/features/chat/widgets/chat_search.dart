import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/chat_service.dart';

/// In-conversation message search delegate.
/// Always scoped to [chatId] — only searches messages in that specific chat.
class ChatSearchDelegate extends SearchDelegate<String?> {
  final String chatId;
  final WidgetRef ref;

  ChatSearchDelegate({required this.chatId, required this.ref});

  @override
  String get searchFieldLabel => 'Search messages...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return theme.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? AppColors.darkBgSecondary
            : AppColors.bgSecondary,
        foregroundColor: isDark
            ? AppColors.darkTextPrimary
            : AppColors.textPrimary,
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
        ),
        border: InputBorder.none,
      ),
      textTheme: theme.textTheme.copyWith(
        // The search field uses titleLarge internally
        titleLarge: TextStyle(
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          fontSize: 18,
        ),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textMuted;
    final bgColor = theme.scaffoldBackgroundColor;

    if (query.trim().isEmpty) {
      return Container(
        color: bgColor,
        child: Center(
          child: Text('Type to search', style: TextStyle(color: mutedColor)),
        ),
      );
    }

    return Container(
      color: bgColor,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _search(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            );
          }

          final messages = List<Map<String, dynamic>>.from(
            snapshot.data?['data']?['messages'] ?? [],
          );

          if (messages.isEmpty) {
            return Center(
              child: Text(
                'No messages found',
                style: TextStyle(color: mutedColor),
              ),
            );
          }

          return ListView.separated(
            itemCount: messages.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              final msg = messages[index];
              final sender = msg['senderId'];
              final currentUser = ref.read(authProvider).user;
              final currentUserId = currentUser?['_id'] ?? '';

              String name = '';
              if (sender is Map) {
                final senderId = sender['_id']?.toString() ?? '';
                name = (senderId == currentUserId)
                    ? 'You'
                    : (sender['name'] ?? '');
              }
              final content = msg['content'] ?? '';
              final createdAt = msg['createdAt'] ?? '';

              String time = '';
              try {
                time = DateFormat(
                  'MMM d, h:mm a',
                ).format(DateTime.parse(createdAt).toLocal());
              } catch (_) {}

              return ListTile(
                tileColor: bgColor,
                leading: CircleAvatar(
                  backgroundColor: AppColors.accentBlue.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
                trailing: Text(
                  time,
                  style: TextStyle(color: mutedColor, fontSize: 11),
                ),
                onTap: () => close(context, msg['_id']),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textMuted;
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: mutedColor),
            const SizedBox(height: 12),
            Text(
              'Search in this conversation',
              style: TextStyle(color: mutedColor),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _search() async {
    final service = ref.read(chatServiceProvider);
    return service.searchMessages(chatId, query);
  }
}
