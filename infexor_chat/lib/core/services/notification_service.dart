import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../constants/api_endpoints.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(apiClientProvider));
});

/// Handles both local notification display and device token management.
class NotificationService {
  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Currently active chat ID — suppress notifications for this chat
  String? activeChatId;

  /// Whether the app UI is in the foreground
  bool isAppInForeground = false;

  /// Map of chatId -> unread message count (since last app open/focus)
  final Map<String, int> _unreadCounts = {};

  NotificationService(this._api);

  /// Initialize the local notifications plugin (call once at app start)
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the notification channel for Android 8+
    const channel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for incoming chat messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Request notification permission (Android 13+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
    debugPrint('✅ NotificationService initialized');
  }

  /// Show a local notification for an incoming message
  Future<void> showMessageNotification({
    required String chatId,
    required String senderName,
    required String messageContent,
    String? senderAvatar,
    bool isGroup = false,
    String? groupName,
  }) async {
    // Don't show notification if user is currently viewing this chat
    if (activeChatId == chatId) return;

    // Don't show banner notification if app is in foreground
    if (isAppInForeground) {
      debugPrint(
        'NotificationService: App in foreground, skipping notification',
      );
      return;
    }

    if (!_initialized) await initialize();

    // Increment count
    _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
    final count = _unreadCounts[chatId]!;

    final title = isGroup && groupName != null
        ? '$senderName • $groupName'
        : senderName;

    final displayBody = count > 1
        ? '$messageContent (+$count messages)'
        : messageContent;

    final String groupKey = 'chat_$chatId';

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for incoming chat messages',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      groupKey: groupKey,
      setAsGroupSummary: false,
      styleInformation: const DefaultStyleInformation(true, true),
    );

    final details = NotificationDetails(android: androidDetails);

    // Use chatId hashCode as notification ID
    await _localNotifications.show(
      id: chatId.hashCode,
      title: title,
      body: displayBody,
      notificationDetails: details,
      payload: chatId,
    );
  }

  /// Clear counts for a chat (call when chat is opened)
  void clearCounts(String chatId) {
    _unreadCounts.remove(chatId);
    _localNotifications.cancelAll();
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    final chatId = response.payload;
    if (chatId != null) {
      debugPrint('Notification tapped for chat: $chatId');
      _unreadCounts.remove(chatId); // Clear on tap
    }
  }

  /// Register device token with backend
  Future<void> registerToken(String token) async {
    try {
      await _api.post(ApiEndpoints.fcmToken, data: {'token': token});
    } catch (e) {
      debugPrint('Failed to register token: $e');
    }
  }

  /// Remove device token from backend (call on logout)
  Future<void> removeToken(String token) async {
    try {
      await _api.delete(ApiEndpoints.fcmToken, data: {'token': token});
    } catch (e) {
      debugPrint('Failed to remove token: $e');
    }
  }
}
