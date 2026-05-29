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

/// Android notification channel for missed calls — separate from messages so
/// they group on their own and can be silenced independently (WhatsApp-style).
const AndroidNotificationChannel missedCallChannel = AndroidNotificationChannel(
  'infexor_missed_calls',
  'Missed calls',
  description: 'Notifications for calls you missed',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);
