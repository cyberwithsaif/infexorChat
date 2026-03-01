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
import 'account_settings_screen.dart';
import '../../../core/localization/locale_provider.dart';
import '../../../generated/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final name = user?['name'] ?? 'User';
    final phone = user?['phone'] ?? '+1 (555) 123-4567';
    final rawAvatar = user?['avatar'] ?? '';
    final avatar = UrlUtils.getFullUrl(rawAvatar);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B141A) : const Color(0xFFFAF8F5);
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.grey[400]! : Colors.grey);

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
          l10n.settings,
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
            onPressed: () {
              showSearch(
                context: context,
                delegate: SettingsSearchDelegate(context, ref, l10n),
              );
            },
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
                              l10n.available,
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
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ─── Account ───
          _SectionHeader(title: l10n.account),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.key_outlined,
                title: l10n.account,
                subtitle: l10n.securityNotifications,
                hasChevron: true,
                onTap: () => Navigator.push(
                  context,
                  AnimatedPageRoute(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
              _Divider(context),
              _SettingsTile(
                icon: Icons.shield_outlined,
                title: l10n.privacy,
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
          _SectionHeader(title: l10n.chats),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.chat_bubble_outline,
                title: l10n.chats,
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
                title: l10n.notifications,
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
                title: l10n.storageAndData,
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
          _SectionHeader(title: l10n.appSettings),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.language,
                title: l10n.appLanguage,
                subtitle: l10n.languageEnglish,
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
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                l10n.chooseLanguage,
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
                              onTap: () {
                                ref
                                    .read(localeProvider.notifier)
                                    .setLocale('en');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              leading: const Text(
                                '🇮🇳',
                                style: TextStyle(fontSize: 24),
                              ),
                              title: Text(l10n.languageHindi),
                              onTap: () {
                                ref
                                    .read(localeProvider.notifier)
                                    .setLocale('hi');
                                Navigator.pop(ctx);
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
          _SectionHeader(title: l10n.help),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline_rounded,
                title: l10n.help,
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
                title: l10n.inviteAFriend,
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
                title: l10n.logout,
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
                        l10n.logout,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      content: Text(
                        l10n.logoutConfirmation,
                        style: TextStyle(color: subtitleColor),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(l10n.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(
                            l10n.logout,
                            style: const TextStyle(color: Colors.redAccent),
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
    this.value,
    this.onChanged,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        titleColor ??
        (theme.textTheme.bodyLarge?.color ??
            (isDark ? Colors.white : Colors.black));
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.grey[400]! : Colors.grey);
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

class SettingsSearchDelegate extends SearchDelegate {
  final BuildContext context;
  final WidgetRef ref;
  final AppLocalizations l10n;

  SettingsSearchDelegate(this.context, this.ref, this.l10n);

  List<Map<String, dynamic>> get _items => [
    {
      'title': l10n.account,
      'icon': Icons.key_rounded,
      'onTap': () => _navigate(const AccountSettingsScreen()),
    },
    {
      'title': l10n.privacy,
      'icon': Icons.lock_outline_rounded,
      'onTap': () => _navigate(const PrivacySettingsScreen()),
    },
    {
      'title': l10n.chats,
      'icon': Icons.chat_outlined,
      'onTap': () => _navigate(const ChatSettingsScreen()),
    },
    {
      'title': l10n.notifications,
      'icon': Icons.notifications_none_rounded,
      'onTap': () => _navigate(const NotificationSettingsScreen()),
    },
    {
      'title': l10n.storageAndData,
      'icon': Icons.data_usage_rounded,
      'onTap': () => _navigate(const StorageDataScreen()),
    },
    {'title': l10n.appLanguage, 'icon': Icons.language_rounded, 'onTap': () {}},
    {
      'title': l10n.help,
      'icon': Icons.help_outline_rounded,
      'onTap': () => _navigate(const HelpScreen()),
    },
    {
      'title': l10n.inviteAFriend,
      'icon': Icons.group_add_outlined,
      'onTap': () {},
    },
  ];

  void _navigate(Widget screen) {
    Navigator.push(context, AnimatedPageRoute(builder: (_) => screen));
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final suggestions = _items.where((item) {
      final title = item['title'].toString().toLowerCase();
      final input = query.toLowerCase();
      return title.contains(input);
    }).toList();

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final item = suggestions[index];
        return ListTile(
          leading: Icon(item['icon'] as IconData),
          title: Text(item['title'] as String),
          onTap: () {
            close(context, null);
            (item['onTap'] as VoidCallback)();
          },
        );
      },
    );
  }
}
