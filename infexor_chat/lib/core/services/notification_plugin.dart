import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shared global notification plugin instance.
/// Both main.dart and NotificationService use this single instance
/// so that tap/action callbacks are handled consistently.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Android notification channel for chat messages.
const AndroidNotificationChannel messageChannel = AndroidNotificationChannel(
  'infexor_messages',
  'Messages',
  description: 'Infexor Chat message notifications',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
  enableVibration: true,
);
