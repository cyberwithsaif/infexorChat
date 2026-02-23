import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class MessageAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const MessageAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

void showMessageActions({
  required BuildContext context,
  required Map<String, dynamic> message,
  required bool isMe,
  required Function(String) onReply,
  required Function() onForward,
  required Function(bool) onDelete,
  required Function(String) onReact,
  required Function() onStar,
  required Function() onCopy,
}) {
  final content = message['content'] ?? '';
  final isStarred = message['isStarred'] ?? false;

  final actions = <MessageAction>[
    MessageAction(
      label: 'Reply',
      icon: Icons.reply_rounded,
      onTap: () {
        Navigator.pop(context);
        onReply(message['_id']);
      },
    ),
    if (content.toString().isNotEmpty)
      MessageAction(
        label: 'Copy',
        icon: Icons.copy_rounded,
        onTap: () {
          Clipboard.setData(ClipboardData(text: content));
          Navigator.pop(context);
          onCopy();
        },
      ),
    MessageAction(
      label: 'Forward',
      icon: Icons.forward_rounded,
      onTap: () {
        Navigator.pop(context);
        onForward();
      },
    ),
    MessageAction(
      label: isStarred ? 'Unstar' : 'Star',
      icon: isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
      onTap: () {
        Navigator.pop(context);
        onStar();
      },
    ),
    MessageAction(
      label: 'Delete for me',
      icon: Icons.delete_outline_rounded,
      onTap: () {
        Navigator.pop(context);
        onDelete(false);
      },
    ),
    if (isMe)
      MessageAction(
        label: 'Delete for everyone',
        icon: Icons.delete_forever_rounded,
        onTap: () {
          Navigator.pop(context);
          onDelete(true);
        },
      ),
  ];

  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Emoji quick-react row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      onReact(emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
            ),

            const Divider(color: AppColors.border, height: 1),

            // Actions
            ...actions.map((action) => ListTile(
                  leading: Icon(action.icon, color: AppColors.textSecondary),
                  title: Text(
                    action.label,
                    style: TextStyle(
                      color: action.label.contains('Delete')
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                  onTap: action.onTap,
                )),

            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
