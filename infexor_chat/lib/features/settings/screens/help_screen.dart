import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  void _copyAndNotify(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label copied to clipboard')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.grey[400]! : Colors.grey);
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Help',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'SUPPORT',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _HelpTile(
            icon: Icons.phone_outlined,
            title: 'Contact Us',
            subtitle: '+91 7007800445',
            onTap: () =>
                _copyAndNotify(context, '+91 7007800445', 'Phone number'),
          ),
          _HelpTile(
            icon: Icons.question_answer_outlined,
            title: 'FAQ',
            subtitle: 'Frequently asked questions',
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: cardColor,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (_) => DraggableScrollableSheet(
                  initialChildSize: 0.7,
                  maxChildSize: 0.9,
                  minChildSize: 0.4,
                  expand: false,
                  builder: (context, scrollController) => ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: Text(
                          'FAQ',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const _FaqItem(
                        question: 'How do I send a message?',
                        answer:
                            'Open a chat and type your message in the text field at the bottom. Tap the send button to send it.',
                      ),
                      const _FaqItem(
                        question: 'How do I create a group?',
                        answer:
                            'Tap the menu button on the chat list and select "New Group". Add participants and set a group name.',
                      ),
                      const _FaqItem(
                        question: 'How do I block a contact?',
                        answer:
                            'Go to the contact\'s profile and tap "Block". You can also manage blocked contacts from Settings > Blocked Contacts.',
                      ),
                      const _FaqItem(
                        question: 'How do I change my privacy settings?',
                        answer:
                            'Go to Settings > Privacy to control who can see your last seen, profile photo, and about.',
                      ),
                      const _FaqItem(
                        question: 'How do I change chat wallpaper?',
                        answer:
                            'Go to Settings > Wallpaper or open a chat and tap the menu to set a per-chat wallpaper.',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Divider(color: AppColors.border, height: 1),

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'LEGAL',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          _HelpTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'infexor.com/privacy',
            onTap: () => _copyAndNotify(
              context,
              'https://infexor.com/privacy',
              'Privacy Policy URL',
            ),
          ),
          _HelpTile(
            icon: Icons.description_outlined,
            title: 'Terms of Service',
            subtitle: 'infexor.com/terms',
            onTap: () => _copyAndNotify(
              context,
              'https://infexor.com/terms',
              'Terms of Service URL',
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // App info
          Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Infexor Chat',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(color: subtitleColor, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Made by infexor',
                    style: TextStyle(color: subtitleColor, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (theme.brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey);

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.accentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.accentBlue, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: subtitleColor, fontSize: 12),
      ),
      trailing: Icon(Icons.chevron_right, color: subtitleColor, size: 20),
      onTap: onTap,
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (theme.brightness == Brightness.dark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (theme.brightness == Brightness.dark ? Colors.grey[400]! : Colors.grey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            answer,
            style: TextStyle(color: subtitleColor, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
        ],
      ),
    );
  }
}
