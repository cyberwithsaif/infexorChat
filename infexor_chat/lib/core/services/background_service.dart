import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../constants/api_endpoints.dart';

// Global flag to track if main app is in foreground
bool isAppInForeground = false;
io.Socket? globalSocket; // Keep track of socket for cleanup

// Helper to stop background ringtone
void _stopBackgroundRingtone() {
  try {
    FlutterRingtonePlayer().stop();
    print('Background Service: Ringtone stopped');
  } catch (_) {}
}

/// Map of chatId -> unread message count in background isolate
final Map<String, int> _unreadCounts = {};

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'foreground_sync_service', // new id to force update
    'Background Sync', // title
    description: 'Keeps the app connected to receive messages',
    importance: Importance.min, // min importance hides it from status bar
    showBadge: false,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
    'chat_channel',
    'Chat Messages',
    description: 'Notifications for new messages',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(chatChannel);

  const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
    'call_channel',
    'Incoming Calls',
    description: 'Notifications for incoming calls',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(callChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // Executed in separate isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      autoStartOnBoot: true, // Restart service after device reboot
      isForegroundMode:
          true, // Run as foreground service to survive app removal from recents

      notificationChannelId: 'foreground_sync_service',
      initialNotificationTitle: 'Infexor Chat',
      initialNotificationContent: 'Syncing messages...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

// Top-level function for background execution
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Hive in this isolate
  await Hive.initFlutter();

  io.Socket? socket;
  String? currentToken;
  Timer? watchdogTimer;
  int reconnectAttempts = 0;
  final int maxReconnectDelay = 60; // Max 60 seconds between retries

  // Helper to connect socket
  void connectSocket(String token) {
    currentToken = token;
    reconnectAttempts = 0;

    if (socket != null) {
      socket!.dispose();
      socket = null;
    }

    // Initialize Socket
    socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(30000)
          .setReconnectionAttempts(double.infinity.toInt())
          .build(),
    );

    socket!.onConnect((_) {
      print('Background Service: Socket connected');
      reconnectAttempts = 0;
      // Safety: If the background service reconnects, assume the app UI is gone.
      // The UI will re-send 'foreground' if it is still alive.
      isAppInForeground = false;
    });

    socket!.onDisconnect((_) {
      print('Background Service: Socket disconnected');
    });

    socket!.onConnectError((error) {
      print('Background Service: Socket connect error: $error');
      reconnectAttempts++;
    });

    socket!.onError((error) {
      print('Background Service: Socket error: $error');
    });

    socket!.onReconnect((_) {
      print('Background Service: Socket reconnected');
      reconnectAttempts = 0;
      // Safety: same logic as onConnect — assume UI is gone
      isAppInForeground = false;
    });

    socket!.onReconnectError((error) {
      print('Background Service: Socket reconnect error: $error');
    });

    // Clear previous listeners to prevent duplicate firing on reconnect
    socket!.off('message:new');
    socket!.off('call:incoming');
    for (final event in [
      'call:ended',
      'call:end',
      'call:reject',
      'call:hangup',
    ]) {
      socket!.off(event);
    }

    socket!.on('message:new', (data) {
      if (data != null && data is Map) {
        // Mark as delivered immediately
        final messageId = data['_id']?.toString();
        if (messageId != null) {
          socket!.emit('message:delivered', {'messageId': messageId});
          print('Background Service: Marked message $messageId as delivered');
        }

        _showNotification(data);
      }
    });

    // Handle incoming calls in background
    socket!.on('call:incoming', (data) {
      if (data != null && data is Map) {
        print('Background Service: Incoming call received');
        _showCallNotification(data);

        // Trigger ringtone here as well for background sound
        try {
          FlutterRingtonePlayer().play(
            android: AndroidSounds.ringtone,
            ios: IosSounds.electronic,
            looping: true,
            volume: 1.0,
          );
        } catch (e) {
          print('Background Service: Error playing ringtone: $e');
        }
      }
    });

    // Stop ringtone if call ends
    for (final event in [
      'call:ended',
      'call:end',
      'call:reject',
      'call:hangup',
    ]) {
      socket!.on(event, (_) => _stopBackgroundRingtone());
    }

    // Connect
    socket!.connect();
  }

  // Watchdog: Periodically check socket health and reconnect if needed
  void startWatchdog() {
    watchdogTimer?.cancel();
    watchdogTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (currentToken == null || currentToken!.isEmpty) {
        return; // No token yet, nothing to do
      }

      final isConnected = socket?.connected ?? false;

      if (!isConnected) {
        reconnectAttempts++;
        // Exponential backoff: only reconnect when the timer aligns with the backoff
        final backoffSeconds = (reconnectAttempts * 2).clamp(
          1,
          maxReconnectDelay,
        );

        // Since timer fires every 15s
        if (reconnectAttempts <= 3 ||
            reconnectAttempts % (backoffSeconds ~/ 15 + 1) == 0) {
          print(
            'Background Service: Watchdog - socket disconnected, reconnecting (attempt $reconnectAttempts)...',
          );

          try {
            if (socket != null) {
              socket!.dispose();
              socket = null;
            }
          } catch (e) {
            print('Background Service: Error disposing old socket: $e');
          }

          connectSocket(currentToken!);
        }
      } else {
        // Socket is connected, reset attempts and send a lightweight ping to combat Android Doze
        reconnectAttempts = 0;
        try {
          socket!.emit('ping', {'source': 'background_watchdog'});
          print('Background Service: Sent Doze-prevention ping');
        } catch (_) {}
      }
    });
  }

  // Try to load token from Hive with robust retries
  // This is critical because when Android restarts the service, the file system
  // might momentarily be locked or unavailable.
  Future<void> initHiveAndConnect() async {
    for (int i = 0; i < 5; i++) {
      try {
        await Hive.openBox('auth');
        await Hive.openBox('contacts_cache');
        await Hive.openBox('server_names');

        final box = Hive.box('auth');
        final token = box.get('accessToken');

        if (token != null && token.toString().isNotEmpty) {
          print(
            'Background Service: Found token in Hive on attempt ${i + 1}, connecting...',
          );
          connectSocket(token);
          return; // Success, exit loop
        } else {
          print('Background Service: Auth box opened but token is null.');
          return; // Box opened successfully, but user is logged out
        }
      } catch (e) {
        print('Background Service: Hive init failed (attempt ${i + 1}): $e');
        if (i < 4) {
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    print(
      'Background Service: FATAL - Could not initialize Hive after 5 attempts.',
    );
  }

  // Fire off the initialization
  initHiveAndConnect();

  // Start the watchdog timer
  startWatchdog();

  // Listen for token updates from UI
  service.on('setToken').listen((event) {
    if (event != null && event['token'] != null) {
      print('Background Service: Received new token from UI');
      connectSocket(event['token']);
    }
  });

  // Listen for App Lifecycle updates from UI
  service.on('setAppStatus').listen((event) {
    if (event != null && event['status'] != null) {
      final status = event['status'];
      print('Background Service: App status changed to $status');
      isAppInForeground = (status == 'foreground');
      if (isAppInForeground) {
        _unreadCounts.clear(); // Wipe background counts when user opens app
      }
    }
  });

  service.on('clearChatCount').listen((event) {
    if (event != null && event['chatId'] != null) {
      _unreadCounts.remove(event['chatId']);
    }
  });

  service.on('stopService').listen((event) {
    watchdogTimer?.cancel();
    socket?.dispose();
    service.stopSelf();
  });
}

// iOS background handler
@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

Future<void> _showNotification(dynamic message) async {
  // Suppress notification if app is in foreground
  if (isAppInForeground) {
    print('Background Service: App is in foreground, suppressing notification');
    return;
  }

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialize if needed (might duplicate logic but safer in background)
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  String title = 'New Message';
  String body = 'You have a new message';
  String? payload; // chatId needed?

  try {
    if (message is Map) {
      // Backend sends 'senderId' as populated object { _id, name, avatar }
      final senderData = message['senderId'];
      final senderId = senderData is Map
          ? senderData['_id']?.toString()
          : senderData?.toString();
      String? savedName;

      // Try device contacts cache first, then server names cache
      try {
        if (senderId != null) {
          if (Hive.isBoxOpen('contacts_cache')) {
            savedName = Hive.box('contacts_cache').get(senderId)?.toString();
          }
          if (savedName == null && Hive.isBoxOpen('server_names')) {
            savedName = Hive.box('server_names').get(senderId)?.toString();
          }
        }
      } catch (e) {
        print('Error getting saved name: $e');
      }

      // Use saved contact name > phone number > server name > fallback
      final serverName = senderData is Map
          ? senderData['name']?.toString()
          : null;
      final phone = senderData is Map ? senderData['phone']?.toString() : null;
      final senderName = savedName ?? phone ?? serverName ?? 'Someone';

      // Build notification body based on message type
      final msgType = message['type']?.toString() ?? 'text';
      String msgBody;
      if (msgType == 'text') {
        msgBody = message['content']?.toString() ?? 'Sent a message';
      } else if (msgType == 'image') {
        msgBody = '📷 Photo';
      } else if (msgType == 'video') {
        msgBody = '🎥 Video';
      } else if (msgType == 'voice' || msgType == 'audio') {
        msgBody = '🎤 Voice message';
      } else if (msgType == 'document') {
        msgBody = '📄 Document';
      } else if (msgType == 'location') {
        msgBody = '📍 Location';
      } else if (msgType == 'gif') {
        msgBody = 'GIF';
      } else {
        msgBody = message['content']?.toString() ?? 'Sent a message';
      }

      title = senderName;
      body = msgBody;
      payload = message['chatId']?.toString();
    }
  } catch (e) {
    print('Error parsing notification content: $e');
  }

  // Count logic
  final chatId = payload ?? 'unknown';
  _unreadCounts[chatId] = (_unreadCounts[chatId] ?? 0) + 1;
  final count = _unreadCounts[chatId]!;

  final displayBody = count > 1 ? '$body (+$count messages)' : body;

  // Show notification
  // Use chatId hashCode as notification ID to group messages from same chat
  final notificationId = payload?.hashCode ?? title.hashCode;
  final String groupKey = 'chat_${payload ?? "default"}';

  await flutterLocalNotificationsPlugin.show(
    id: notificationId, // One ID per chat to update existing notification
    title: title,
    body: displayBody,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_channel', // Must match the channel ID created in Main App
        'Chat Messages',
        importance: Importance.max,
        priority: Priority.high,
        groupKey: groupKey,
        setAsGroupSummary: false,
        styleInformation: const DefaultStyleInformation(true, true),
      ),
    ),
    payload: payload,
  );
}

Future<void> _showCallNotification(dynamic data) async {
  // Suppress if app is in foreground (CallManager handles it)
  if (isAppInForeground) {
    print(
      'Background Service: App is in foreground, skipping call notification',
    );
    return;
  }

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
  );

  String callerName = 'Unknown';
  String callType = 'Voice';

  try {
    if (data is Map) {
      // Extract caller name from various possible fields
      final callerData = data['caller'] ?? data['callerInfo'];
      if (callerData is Map) {
        callerName = callerData['name']?.toString() ?? 'Unknown';
      }
      if (callerName == 'Unknown') {
        callerName = data['callerName']?.toString() ?? 'Unknown';
      }
      if (callerName == 'Unknown') {
        callerName = data['callerPhone']?.toString() ?? 'Unknown';
      }

      // Try Hive caches
      final callerId = data['callerId']?.toString();
      if (callerName == 'Unknown' && callerId != null) {
        try {
          if (Hive.isBoxOpen('contacts_cache')) {
            final cached = Hive.box('contacts_cache').get(callerId)?.toString();
            if (cached != null && cached.isNotEmpty) callerName = cached;
          }
          if (callerName == 'Unknown' && Hive.isBoxOpen('server_names')) {
            final cached = Hive.box('server_names').get(callerId)?.toString();
            if (cached != null && cached.isNotEmpty) callerName = cached;
          }
        } catch (_) {}
      }

      final type = data['type']?.toString();
      if (type == 'video') callType = 'Video';
    }
  } catch (e) {
    print('Error parsing call notification: $e');
  }

  // Show a high-priority full-screen notification for calls
  await flutterLocalNotificationsPlugin.show(
    id: 999, // Fixed ID for call notifications
    title: 'Incoming $callType Call',
    body: callerName,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'call_channel',
        'Incoming Calls',
        importance: Importance.max,
        priority: Priority.max,
        category: AndroidNotificationCategory.call,
        fullScreenIntent: true,
        ongoing: true,
        autoCancel: false,
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
      ),
    ),
  );
}
