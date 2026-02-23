import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'all_media_gallery_screen.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/animated_page_route.dart';

class StorageDataScreen extends ConsumerStatefulWidget {
  const StorageDataScreen({super.key});

  @override
  ConsumerState<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends ConsumerState<StorageDataScreen> {
  String _autoDownloadWifi = 'all';
  String _autoDownloadMobile = 'none';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDownloadWifi = prefs.getString('auto_dl_wifi') ?? 'all';
      _autoDownloadMobile = prefs.getString('auto_dl_mobile') ?? 'none';
    });
  }

  Future<void> _savePref(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<void> _showDownloadPicker(
    String title,
    String current,
    Function(String) onChanged,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    final options = [
      {'value': 'all', 'label': 'All media'},
      {'value': 'images', 'label': 'Images only'},
      {'value': 'none', 'label': 'No media'},
    ];

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...options.map(
            (opt) => RadioListTile<String>(
              title: Text(
                opt['label']!,
                style: TextStyle(color: textColor),
              ),
              value: opt['value']!,
              groupValue: current,
              activeColor: AppColors.accentBlue,
              onChanged: (val) => Navigator.pop(ctx, val),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );

    if (result != null) {
      onChanged(result);
    }
  }

  String _displayLabel(String value) {
    switch (value) {
      case 'all':
        return 'All media';
      case 'images':
        return 'Images only';
      case 'none':
        return 'No media';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Storage & Data',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        children: [
          // Auto-Download Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'AUTO-DOWNLOAD MEDIA',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ListTile(
            title: Text(
              'When using Wi-Fi',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayLabel(_autoDownloadWifi),
                  style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: subtitleColor,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _showDownloadPicker(
              'Auto-download on Wi-Fi',
              _autoDownloadWifi,
              (val) {
                setState(() => _autoDownloadWifi = val);
                _savePref('auto_dl_wifi', val);
              },
            ),
          ),
          ListTile(
            title: Text(
              'When using mobile data',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayLabel(_autoDownloadMobile),
                  style: const TextStyle(
                    color: AppColors.accentBlue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: subtitleColor,
                  size: 20,
                ),
              ],
            ),
            onTap: () => _showDownloadPicker(
              'Auto-download on Mobile Data',
              _autoDownloadMobile,
              (val) {
                setState(() => _autoDownloadMobile = val);
                _savePref('auto_dl_mobile', val);
              },
            ),
          ),

          const Divider(color: AppColors.border, height: 1),

          // Storage Info
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'STORAGE',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                color: AppColors.accentBlue,
                size: 20,
              ),
            ),
            title: Text(
              'Manage Storage',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'View all photos and videos from your chats',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: subtitleColor,
              size: 20,
            ),
            onTap: () {
              Navigator.push(
                context,
                AnimatedPageRoute(
                  builder: (_) => const AllMediaGalleryScreen(),
                ),
              );
            },
          ),
          const Divider(color: AppColors.border, height: 1, indent: 64),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: AppColors.accentBlue,
                size: 20,
              ),
            ),
            title: Text(
              'Clear Cache',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Free up space by clearing cached data',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: cardColor,
                  title: Text(
                    'Clear Cache',
                    style: TextStyle(color: textColor),
                  ),
                  content: Text(
                    'This will clear all cached images and data. Are you sure?',
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
                        'Clear',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true && mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Cache cleared')));
              }
            },
          ),
        ],
      ),
    );
  }
}
