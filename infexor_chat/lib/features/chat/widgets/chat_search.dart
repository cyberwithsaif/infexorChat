import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../services/chat_service.dart';

class ChatSearchDelegate extends SearchDelegate<String?> {
  final String chatId;
  final WidgetRef ref;

  ChatSearchDelegate({required this.chatId, required this.ref});

  @override
  String get searchFieldLabel => 'Search messages...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgSecondary,
        foregroundColor: AppColors.textPrimary,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.textMuted),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
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
    if (query.trim().isEmpty) {
      return const Center(
        child: Text('Type to search', style: TextStyle(color: AppColors.textMuted)),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _search(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.accentBlue),
          );
        }

        final messages = List<Map<String, dynamic>>.from(
            snapshot.data?['data']?['messages'] ?? []);

        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages found',
                style: TextStyle(color: AppColors.textMuted)),
          );
        }

        return ListView.builder(
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final sender = msg['senderId'];
            final name = sender is Map ? sender['name'] ?? '' : '';
            final content = msg['content'] ?? '';
            final createdAt = msg['createdAt'] ?? '';

            String time = '';
            try {
              time = DateFormat('MMM d, h:mm a')
                  .format(DateTime.parse(createdAt).toLocal());
            } catch (_) {}

            return ListTile(
              title: Text(name,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500)),
              subtitle: Text(content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary)),
              trailing: Text(time,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11)),
              onTap: () => close(context, msg['_id']),
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return const Center(
      child: Text('Search in this conversation',
          style: TextStyle(color: AppColors.textMuted)),
    );
  }

  Future<Map<String, dynamic>> _search() async {
    final service = ref.read(chatServiceProvider);
    return service.searchMessages(chatId, query);
  }
}
