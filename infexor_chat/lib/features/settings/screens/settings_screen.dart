import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../../core/utils/animation_helpers.dart';
import '../../auth/providers/auth_provider.dart';
import 'privacy_settings_screen.dart';
import 'profile_edit_screen.dart';
import 'blocked_contacts_screen.dart';
import 'notification_settings_screen.dart';
import 'storage_data_screen.dart';
import 'help_screen.dart';
import 'chat_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final name = user?['name'] ?? 'User';
    final about = user?['about'] ?? '';
    final rawAvatar = user?['avatar'] ?? '';
    final avatar = UrlUtils.getFullUrl(rawAvatar);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFE9EDEF);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: IconThemeData(color: subtitleColor),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: subtitleColor),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: subtitleColor),
            color: bgColor,
            onSelected: (value) {},
            itemBuilder: (ctx) => [],
          ),
        ],
      ),
      body: ListView(
        children: [
          // Profile header card
          TapScaleFeedback(
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isDark
                        ? const Color(0xFF2A2F32)
                        : const Color(0xFFE8EDF2),
                    backgroundImage: avatar.isNotEmpty
                        ? CachedNetworkImageProvider(avatar)
                        : null,
                    child: avatar.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  // Name + About
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          about.isNotEmpty
                              ? about
                              : 'Hey there! I am using Infexor Chat',
                          style: TextStyle(color: subtitleColor, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Divider(color: dividerColor, height: 1),
          const SizedBox(height: 4),

          // ─── SETTINGS ITEMS ───
          _SettingsTile(
            icon: Icons.person_outline_rounded,
            iconBgColor: const Color(0xFF2196F3),
            title: 'Account',
            subtitle: 'Number, Bio',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const ProfileEditScreen()),
            ),
          ),

          _SettingsTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconBgColor: const Color(0xFF4CAF50),
            title: 'Chat Settings',
            subtitle: 'Theme, Wallpaper, Animations',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const ChatSettingsScreen()),
            ),
          ),

          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            iconBgColor: const Color(0xFF009688),
            title: 'Privacy & Security',
            subtitle: 'Last Seen, Devices, Passkeys',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const PrivacySettingsScreen()),
            ),
          ),

          _SettingsTile(
            icon: Icons.notifications_outlined,
            iconBgColor: const Color(0xFFFF5722),
            title: 'Notifications',
            subtitle: 'Sounds, Calls, Badges',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),

          _SettingsTile(
            icon: Icons.data_usage_rounded,
            iconBgColor: const Color(0xFF8BC34A),
            title: 'Data and Storage',
            subtitle: 'Media download settings',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const StorageDataScreen()),
            ),
          ),

          _SettingsTile(
            icon: Icons.folder_outlined,
            iconBgColor: const Color(0xFF3F51B5),
            title: 'Chat Folders',
            subtitle: 'Sort chats into folders',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          _SettingsTile(
            icon: Icons.devices_rounded,
            iconBgColor: const Color(0xFF607D8B),
            title: 'Devices',
            subtitle: 'Manage connected devices',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          _SettingsTile(
            icon: Icons.battery_saver_rounded,
            iconBgColor: const Color(0xFFFF9800),
            title: 'Power Saving',
            subtitle: 'Reduce power usage on low charge',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          _SettingsTile(
            icon: Icons.language_rounded,
            iconBgColor: const Color(0xFF9C27B0),
            title: 'Language',
            subtitle: 'English',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Coming soon'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),

          Divider(color: dividerColor, height: 1),

          // Help
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            iconBgColor: const Color(0xFF2196F3),
            title: 'Help',
            subtitle: 'Contact us, privacy policy',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const HelpScreen()),
            ),
          ),

          // Blocked contacts
          _SettingsTile(
            icon: Icons.block_rounded,
            iconBgColor: const Color(0xFFE53935),
            title: 'Blocked Contacts',
            subtitle: 'Manage blocked users',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(builder: (_) => const BlockedContactsScreen()),
            ),
          ),

          Divider(color: dividerColor, height: 1),

          // Logout
          _SettingsTile(
            icon: Icons.logout_rounded,
            iconBgColor: const Color(0xFFE53935),
            title: 'Logout',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Text(
                    'Logout',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  content: Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(color: subtitleColor),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        'Logout',
                        style: TextStyle(color: Color(0xFFE53935)),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                ref.read(authProvider.notifier).logout();
              }
            },
          ),

          const SizedBox(height: 24),

          // App info
          Center(
            child: Column(
              children: [
                Text(
                  'Infexor Chat',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: subtitleColor, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashFactory: InkRipple.splashFactory,
        highlightColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Colored circle icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 16),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(color: subtitleColor, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
