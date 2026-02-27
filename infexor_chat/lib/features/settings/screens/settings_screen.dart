import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../../core/utils/animation_helpers.dart';
import '../../auth/providers/auth_provider.dart';
import 'privacy_settings_screen.dart';
import 'profile_edit_screen.dart';
import 'notification_settings_screen.dart';
import 'storage_data_screen.dart';
import 'help_screen.dart';
import 'chat_settings_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final name = user?['name'] ?? 'User';
    final phone = user?['phone'] ?? '+1 (555) 123-4567';
    final rawAvatar = user?['avatar'] ?? '';
    final avatar = UrlUtils.getFullUrl(rawAvatar);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFFAF8F5);
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.primaryPurple),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: Text(
          'Settings',
          style: TextStyle(
            color: AppColors.primaryPurple,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: IconThemeData(color: subtitleColor),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: dividerColor(context), height: 1),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: subtitleColor),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 40),
        children: [
          // ─── Profile Header ───
          _SettingsCard(
            children: [
              TapScaleFeedback(
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(builder: (_) => const ProfileEditScreen()),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundColor: isDark
                                ? const Color(0xFF2A2F32)
                                : const Color(0xFFE8EDF2),
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: subtitleColor,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: AppColors.primaryPurple,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Name + Meta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: AppColors.primaryPurple,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Available',
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              phone,
                              style: TextStyle(
                                color: subtitleColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // QR Code Icon
                      Icon(
                        Icons.qr_code_2,
                        color: AppColors.primaryPurple,
                        size: 32,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Account ───
          const _SectionHeader(title: 'Account'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.key_outlined,
                title: 'Account',
                subtitle: 'Security notifications, change number',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                ),
              ),
              _Divider(context),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: 'Privacy',
                subtitle: 'Block contacts, disappearing messages',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(
                    builder: (_) => const PrivacySettingsScreen(),
                  ),
                ),
              ),
            ],
          ),

          // ─── Chats & Media ───
          const _SectionHeader(title: 'Chats & Media'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.chat_bubble_outline,
                title: 'Chats',
                subtitle: 'Theme, wallpapers, chat history',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(builder: (_) => const ChatSettingsScreen()),
                ),
              ),
              _Divider(context),
              _SettingsTile(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Message, group & call tones',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(
                    builder: (_) => const NotificationSettingsScreen(),
                  ),
                ),
              ),
              _Divider(context),
              _SettingsTile(
                icon: Icons.data_usage,
                title: 'Storage and Data',
                subtitle: 'Network usage, auto-download',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(builder: (_) => const StorageDataScreen()),
                ),
              ),
            ],
          ),

          // ─── App Settings ───
          const _SectionHeader(title: 'App Settings'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.language,
                title: 'App Language',
                subtitle: 'English (device\'s language)',
                hasChevron: true,
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: isDark
                        ? AppColors.darkBgSecondary
                        : Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 12, bottom: 8),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Choose Language',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Text(
                                '🇺🇸',
                                style: TextStyle(fontSize: 24),
                              ),
                              title: const Text('English'),
                              trailing: const Icon(
                                Icons.check,
                                color: Colors.green,
                              ),
                              onTap: () => Navigator.pop(ctx),
                            ),
                            ListTile(
                              leading: const Text(
                                '🇮🇳',
                                style: TextStyle(fontSize: 24),
                              ),
                              title: const Text('हिन्दी (Hindi)'),
                              onTap: () {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Hindi language coming soon!',
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),

          // ─── Help ───
          const _SectionHeader(title: 'Help'),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help',
                subtitle: 'Help center, contact us, privacy policy',
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(builder: (_) => const HelpScreen()),
                ),
              ),
              _Divider(context),
              _SettingsTile(
                icon: Icons.group_add_outlined,
                title: 'Invite a Friend',
                hasChevron: true,
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Logout ───
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Logout',
                iconColor: Colors.redAccent,
                titleColor: Colors.redAccent,
                hasChevron: false,
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
                            style: TextStyle(color: Colors.redAccent),
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
            ],
          ),
        ],
      ),
    );
  }

  Color dividerColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.withValues(alpha: 0.1)
        : const Color(0xFFF0F2F5);
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: subtitleColor.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202C33) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  final BuildContext context;
  const _Divider(this.context);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark
          ? Colors.grey.withValues(alpha: 0.1)
          : const Color(0xFFF6F8FA),
      indent: 56,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool hasChevron;
  final bool? value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onTap;

  final Color? iconColor;
  final Color? titleColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.hasChevron = false,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        titleColor ??
        (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black);
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final activeIconColor = iconColor ?? AppColors.primaryPurple;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: activeIconColor, size: 22),
              const SizedBox(width: 16),
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
              if (hasChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: subtitleColor.withValues(alpha: 0.5),
                  size: 20,
                ),
              if (value != null && onChanged != null)
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: value!,
                    onChanged: onChanged,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primaryPurple,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey.withValues(alpha: 0.3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
