class ReplyPreview extends StatelessWidget {
  final Map<String, dynamic>? replyTo;
  final bool isMe;

  const ReplyPreview({super.key, this.replyTo, required this.isMe});

  @override
  Widget build(BuildContext context) {
    if (replyTo == null) return const SizedBox.shrink();

    final content = replyTo!['content'] ?? 'Media';
    final sender = replyTo!['senderId'];
    final senderName = (sender is Map)
        ? (sender['name'] ?? 'Unknown')
        : 'Unknown';
    final type = replyTo!['type'] ?? 'text';

    IconData? icon;
    if (type == 'image') {
      icon = Icons.image;
    } else if (type == 'video')
      icon = Icons.videocam;
    else if (type == 'voice' || type == 'audio')
      icon = Icons.mic;
    else if (type == 'document')
      icon = Icons.insert_drive_file;
    else if (type == 'location')
      icon = Icons.location_on;
    else if (type == 'contact')
      icon = Icons.person;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: AppColors.accentBlue, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.accentBlue,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  content.toString().isEmpty ? type : content.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
