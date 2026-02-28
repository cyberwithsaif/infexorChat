import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../constants/api_endpoints.dart';
import 'notification_plugin.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(apiClientProvider));
});

/// Handles both local notification display and device token management.
class NotificationService {
  final ApiClient _api;

  /// Currently active chat ID — suppress notifications for this chat
  String? activeChatId;

  /// Whether the app UI is in the foreground
  bool isAppInForeground = false;

  /// Accumulated messages per chat for MessagingStyleInformation (WhatsApp-style grouping)
  final Map<String, List<Message>> _messageHistory = {};

  bool _permissionRequested = false;

  NotificationService(this._api);

  /// Request notification permission (Android 13+).
  /// Plugin initialization is handled in main.dart.
  Future<void> initialize() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Show a local notification for an incoming message.
  /// Groups multiple messages from the same chat using MessagingStyleInformation.
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

    // Accumulate messages per chat for grouped display
    _messageHistory.putIfAbsent(chatId, () => []);
    _messageHistory[chatId]!.add(
      Message(
        messageContent,
        DateTime.now(),
        Person(name: senderName),
      ),
    );

    final title = isGroup && groupName != null
        ? '$senderName • $groupName'
        : senderName;

    // Build WhatsApp-style grouped notification using MessagingStyleInformation
    final messages = _messageHistory[chatId]!;
    final messagingStyle = MessagingStyleInformation(
      Person(name: 'Me'),
      conversationTitle: isGroup ? groupName : null,
      groupConversation: isGroup,
      messages: messages,
    );

    final androidDetails = AndroidNotificationDetails(
      messageChannel.id,
      messageChannel.name,
      channelDescription: messageChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: messageChannel.sound,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      groupKey: 'chat_$chatId',
      styleInformation: messagingStyle,
      actions: const [
        AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: [AndroidNotificationActionInput(label: 'Type a message...')],
          showsUserInterface: false,
          cancelNotification: false,
        ),
        AndroidNotificationAction(
          'mark_read_action',
          'Mark as read',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    // Use chatId hashCode as notification ID — same chat replaces its own grouped notification
    await flutterLocalNotificationsPlugin.show(
      id: chatId.hashCode,
      title: title,
      body: messageContent,
      notificationDetails: NotificationDetails(android: androidDetails),
      payload: chatId,
    );
  }

  /// Clear message history for a chat (call when chat is opened)
  void clearCounts(String chatId) {
    _messageHistory.remove(chatId);
    flutterLocalNotificationsPlugin.cancel(id: chatId.hashCode);
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
