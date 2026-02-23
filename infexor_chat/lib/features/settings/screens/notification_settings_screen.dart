import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  bool _messageNotifications = true;
  bool _groupNotifications = true;
  bool _callNotifications = true;
  bool _showPreview = true;
  bool _vibrate = true;
  bool _sound = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _messageNotifications = prefs.getBool('notif_messages') ?? true;
      _groupNotifications = prefs.getBool('notif_groups') ?? true;
      _callNotifications = prefs.getBool('notif_calls') ?? true;
      _showPreview = prefs.getBool('notif_preview') ?? true;
      _vibrate = prefs.getBool('notif_vibrate') ?? true;
      _sound = prefs.getBool('notif_sound') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Notifications',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        children: [
          // Message Notifications Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'MESSAGES',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
              'Message Notifications',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Show notifications for new messages',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _messageNotifications,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _messageNotifications = val);
              _savePref('notif_messages', val);
            },
          ),
          SwitchListTile(
            title: Text(
              'Group Notifications',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Show notifications for group messages',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _groupNotifications,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _groupNotifications = val);
              _savePref('notif_groups', val);
            },
          ),

          const Divider(color: AppColors.border, height: 1),

          // Calls Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'CALLS',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
              'Call Notifications',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Show notifications for incoming calls',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _callNotifications,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _callNotifications = val);
              _savePref('notif_calls', val);
            },
          ),

          const Divider(color: AppColors.border, height: 1),

          // General Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'GENERAL',
              style: TextStyle(
                color: AppColors.accentBlue,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SwitchListTile(
            title: Text(
              'Show Preview',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Show message content in notification',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _showPreview,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _showPreview = val);
              _savePref('notif_preview', val);
            },
          ),
          SwitchListTile(
            title: Text(
              'Sound',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Play sound for notifications',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _sound,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _sound = val);
              _savePref('notif_sound', val);
            },
          ),
          SwitchListTile(
            title: Text(
              'Vibrate',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Vibrate for notifications',
              style: TextStyle(color: subtitleColor, fontSize: 12),
            ),
            value: _vibrate,
            activeThumbColor: AppColors.accentBlue,
            onChanged: (val) {
              setState(() => _vibrate = val);
              _savePref('notif_vibrate', val);
            },
          ),
        ],
      ),
    );
  }
}
