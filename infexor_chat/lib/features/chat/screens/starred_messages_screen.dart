import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';

/// Screen that shows all messages the user has starred (bookmarked).
/// Starred messages are stored locally in Hive under 'starred_messages' box.
class StarredMessagesScreen extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const StarredMessagesScreen({super.key, this.chatId, this.chatName});

  @override
  State<StarredMessagesScreen> createState() => _StarredMessagesScreenState();

  static Future<void> starMessage(Map<String, dynamic> message) async {
    final box = await Hive.openBox('starred_messages');
    final msgId = message['_id']?.toString() ?? '';
    if (msgId.isEmpty) return;
    await box.put(msgId, jsonEncode(message));
  }

  static Future<void> unstarMessage(String messageId) async {
    final box = await Hive.openBox('starred_messages');
    await box.delete(messageId);
  }

  static bool isStarred(String messageId) {
    if (!Hive.isBoxOpen('starred_messages')) return false;
    return Hive.box('starred_messages').containsKey(messageId);
  }
}

class _StarredMessagesScreenState extends State<StarredMessagesScreen> {
  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadStarred();
  }

  Future<void> _loadStarred() async {
    final box = await Hive.openBox('starred_messages');
    final all = box.values
        .map((v) {
          try {
            return jsonDecode(v as String) as Map<String, dynamic>;
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    final filtered = widget.chatId != null
        ? all
              .where(
                (m) =>
                    (m['chatId']?.toString() ?? m['chat']?.toString() ?? '') ==
                    widget.chatId,
              )
              .toList()
        : all;

    filtered.sort((a, b) {
      final at = a['createdAt']?.toString() ?? '';
      final bt = b['createdAt']?.toString() ?? '';
      return bt.compareTo(at);
    });

    if (mounted) setState(() => _messages = filtered);
  }

  Future<void> _unstar(String msgId) async {
    await StarredMessagesScreen.unstarMessage(msgId);
    _messages.removeWhere((m) => m['_id']?.toString() == msgId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final appBarBg = isDark ? AppColors.darkBgSecondary : Colors.white;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final mutedColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF8696A0);

    final title = widget.chatName != null
        ? 'Starred in ${widget.chatName}'
        : 'Starred Messages';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarBg,
        iconTheme: IconThemeData(color: textColor),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: textColor, fontSize: 17)),
            if (_messages.isNotEmpty)
              Text(
                '${_messages.length} message${_messages.length == 1 ? '' : 's'}',
                style: TextStyle(color: subtitleColor, fontSize: 12),
              ),
          ],
        ),
      ),
      body: _messages.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_border_rounded, size: 72, color: mutedColor),
                  const SizedBox(height: 16),
                  Text(
                    'No starred messages',
                    style: TextStyle(
                      fontSize: 18,
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Long-press a message and tap the ⭐ icon to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: mutedColor),
                    ),
                  ),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _messages.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 72, color: theme.dividerColor),
              itemBuilder: (context, i) {
                final msg = _messages[i];
                final msgId = msg['_id']?.toString() ?? '';
                final content = msg['content']?.toString() ?? '';
                final type = msg['type']?.toString() ?? 'text';
                final createdAt = msg['createdAt']?.toString() ?? '';
                final sender = msg['senderId'];
                final senderName = sender is Map
                    ? sender['name']?.toString() ?? 'Unknown'
                    : 'Unknown';

                String timeStr = '';
                try {
                  timeStr = DateFormat(
                    'MMM d, h:mm a',
                  ).format(DateTime.parse(createdAt).toLocal());
                } catch (_) {}

                String subtitle = content;
                IconData typeIcon = Icons.message;
                if (type == 'image') {
                  subtitle = '📷 Photo';
                  typeIcon = Icons.image;
                } else if (type == 'video') {
                  subtitle = '🎥 Video';
                  typeIcon = Icons.videocam;
                } else if (type == 'audio') {
                  subtitle = '🎙 Audio';
                  typeIcon = Icons.mic;
                } else if (type == 'document') {
                  subtitle = '📄 Document';
                  typeIcon = Icons.attach_file;
                }

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.accentBlue.withValues(
                      alpha: 0.1,
                    ),
                    child: Icon(
                      typeIcon,
                      color: AppColors.accentBlue,
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          senderName,
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(color: subtitleColor, fontSize: 11),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.star, color: Colors.amber),
                    tooltip: 'Unstar',
                    onPressed: () => _unstar(msgId),
                  ),
                );
              },
            ),
    );
  }
}
