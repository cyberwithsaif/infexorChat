import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../../core/theme/theme_provider.dart';
import 'wallpaper_selection_screen.dart';

class ChatSettingsScreen extends ConsumerWidget {
  const ChatSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Chat Settings',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        children: [
          // Theme Selection
          _SettingsTile(
            icon: Icons.palette_outlined,
            iconBgColor: const Color(0xFF673AB7),
            title: 'Appearance',
            subtitle: 'Theme (Light, Dark, System)',
            onTap: () => _showThemeDialog(context, ref),
          ),

          // Wallpaper Selection
          _SettingsTile(
            icon: Icons.wallpaper_rounded,
            iconBgColor: const Color(0xFF4CAF50),
            title: 'Wallpaper',
            subtitle: 'Chat background',
            onTap: () => Navigator.push(
              context,
              AnimatedPageRoute(
                builder: (_) => const WallpaperSelectionScreen(),
              ),
            ),
          ),

          Divider(color: dividerColor, height: 1),
        ],
      ),
    );
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.read(themeProvider);
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: bgColor,
          title: Text(
            'Choose Theme',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<ThemeMode>(
                title: Text(
                  'System default',
                  style: TextStyle(color: textColor),
                ),
                value: ThemeMode.system,
                groupValue: currentTheme,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('Light', style: TextStyle(color: textColor)),
                value: ThemeMode.light,
                groupValue: currentTheme,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
              RadioListTile<ThemeMode>(
                title: Text('Dark', style: TextStyle(color: textColor)),
                value: ThemeMode.dark,
                groupValue: currentTheme,
                onChanged: (val) {
                  if (val != null) {
                    ref.read(themeProvider.notifier).setThemeMode(val);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
        );
      },
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
