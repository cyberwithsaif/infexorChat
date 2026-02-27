import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'config/routes.dart';

import 'core/services/call_manager.dart';
import 'core/widgets/active_call_banner.dart';
import 'core/widgets/active_call_pip.dart';
import 'features/auth/services/auth_service.dart';
import 'features/contacts/providers/contact_provider.dart';
import 'features/chat/screens/conversation_screen.dart';

// ─── Global notification plugin (message notifications only) ────────────────
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Android notification channel for chat messages
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'infexor_messages',
  'Messages',
  description: 'Infexor Chat message notifications',
  importance: Importance.high,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('notification_sound'),
  enableVibration: true,
);

// ─── Call payload helpers ────────────────────────────────────────────────────

/// True if FCM data is an active incoming call (not a missed-call receipt).
bool isCallPayload(Map<String, dynamic> data) {
  final t = data['type']?.toString() ?? '';
  final s = data['status']?.toString() ?? '';
  if (s == 'missed' || t == 'missed_call') return false;
  return t == 'call' || t == 'video_call' || t == 'audio_call';
}

/// True if FCM data is a call-control signal (cancel or busy).
bool isCallControlPayload(Map<String, dynamic> data) {
  final t = data['type']?.toString() ?? '';
  return t == 'call_cancel' || t == 'call_busy';
}

/// Show a native OS incoming-call UI via flutter_callkit_incoming.
/// Works in background isolate — no Flutter widget tree needed.
Future<void> showCallkitIncoming(Map<String, dynamic> data) async {
  final chatId    = data['chatId']?.toString() ?? '';
  final callerName  = data['callerName']?.toString() ?? 'Unknown';
  final callerAvatar = data['callerAvatar']?.toString() ?? '';
  final isVideo   = data['type'] == 'video_call';

  final params = CallKitParams(
    id: chatId,
    nameCaller: callerName,
    appName: 'Infexor Chat',
    avatar: callerAvatar.isNotEmpty ? callerAvatar : null,
    type: isVideo ? 1 : 0,   // 0 = voice, 1 = video
    duration: 30000,          // 30-second auto-timeout
    textAccept: 'Accept',
    textDecline: 'Decline',
    // Store all fields needed when the user taps Accept
    extra: {
      'chatId':       chatId,
      'callerId':     data['callerId']?.toString() ?? '',
      'callerName':   callerName,
      'callerAvatar': callerAvatar,
      'isVideo':      isVideo.toString(),
    },
    android: const AndroidParams(
      isCustomNotification: true,
      isShowLogo: false,
      ringtonePath: 'system_ringtone_default',
      backgroundColor: '#0A0A0F',
      actionColor: '#4CAF50',
      incomingCallNotificationChannelName: 'Incoming Calls',
      missedCallNotificationChannelName: 'Missed Calls',
    ),
  );

  await FlutterCallkitIncoming.showCallkitIncoming(params);
}

// ─── Background FCM handler ──────────────────────────────────────────────────

/// Runs in a separate Dart isolate when a FCM message arrives while the app
/// is killed or in background.  Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final data = message.data;
  if (isCallPayload(data)) {
    // Show the native OS incoming-call screen — no Flutter UI needed.
    await showCallkitIncoming(data);
  } else if (isCallControlPayload(data)) {
    // Cancel or busy signal — dismiss any showing callkit UI.
    final chatId = data['chatId']?.toString() ?? '';
    if (chatId.isNotEmpty) {
      await FlutterCallkitIncoming.endCall(chatId);
    }
  }
}

// ─── Pending message navigation (terminated state) ──────────────────────────
String? _pendingMessageChatId;
bool _isNavigatingToChat = false;

void _navigateToChatScreen(String chatId) {
  if (_isNavigatingToChat) return;
  _isNavigatingToChat = true;
  flutterLocalNotificationsPlugin.cancel(id: chatId.hashCode);
  navigatorKey.currentState
      ?.push(
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            chatId: chatId,
            chatName: 'Chat',
            chatAvatar: '',
            isOnline: false,
          ),
        ),
      )
      .then((_) => _isNavigatingToChat = false);
}

/// Handles taps on message local-notifications (payload = chatId string).
void _onNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty || payload.startsWith('{')) return;
  if (navigatorKey.currentState != null) {
    _navigateToChatScreen(payload);
  } else {
    _pendingMessageChatId = payload;
  }
}

// ─── main ────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Local notifications — only used for chat message banners now.
  // Incoming call UI is entirely handled by flutter_callkit_incoming.
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(
    settings: initSettings,
    onDidReceiveNotificationResponse: _onNotificationResponse,
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(channel);

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('messages_cache');

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Check if a *message* notification launched the app from terminated state
  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true) {
    final payload = launchDetails?.notificationResponse?.payload;
    if (payload != null && payload.isNotEmpty && !payload.startsWith('{')) {
      _pendingMessageChatId = payload;
    }
  }

  runApp(const ProviderScope(child: InfexorChatApp()));
}

// ─── Root widget ─────────────────────────────────────────────────────────────

class InfexorChatApp extends ConsumerStatefulWidget {
  const InfexorChatApp({super.key});
  @override
  ConsumerState<InfexorChatApp> createState() => _InfexorChatAppState();
}

class _InfexorChatAppState extends ConsumerState<InfexorChatApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      // CallManager.init() also registers the flutter_callkit_incoming listener
      ref.read(callManagerProvider).init();
      ref.read(contactProvider.notifier).syncContacts();
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      ref.read(authServiceProvider).updateFcmToken(token);
    });

    // FCM tap while app was in background — calls are handled by callkit,
    // so only route message taps here.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final data = message.data;
      if (isCallPayload(data)) return; // CallManager handles via callkit event
      final chatId = data['chatId']?.toString() ?? '';
      if (chatId.isNotEmpty) {
        flutterLocalNotificationsPlugin.cancel(id: chatId.hashCode);
        if (navigatorKey.currentState != null) {
          _navigateToChatScreen(chatId);
        } else {
          _pendingMessageChatId = chatId;
        }
      }
    });

    // Foreground FCM messages — calls handled by socket in CallManager
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (isCallPayload(data)) return;

      final notification = message.notification;
      if (notification != null) {
        final chatId = data['chatId']?.toString() ?? '';
        final notificationId =
            chatId.isNotEmpty ? chatId.hashCode : notification.hashCode;

        flutterLocalNotificationsPlugin.show(
          id: notificationId,
          title: notification.title,
          body: notification.body,
          payload: chatId,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
              sound: const RawResourceAndroidNotificationSound(
                  'notification_sound'),
              enableVibration: true,
              vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
            ),
          ),
        );
      }
    });

    // Process any pending message navigation from terminated state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatId = _pendingMessageChatId;
      _pendingMessageChatId = null;
      if (chatId != null && chatId.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          _navigateToChatScreen(chatId);
        });
      }
    });

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {}

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) {
        final themeMode = ref.watch(themeProvider);
        return MaterialApp.router(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          showPerformanceOverlay: const bool.fromEnvironment(
            'SHOW_PERF',
            defaultValue: false,
          ),
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          routerConfig: router,
          builder: (context, child) {
            return Stack(
              children: [
                Column(
                  children: [
                    const ActiveCallBanner(),
                    Expanded(child: child ?? const SizedBox.shrink()),
                  ],
                ),
                const ActiveCallPip(),
              ],
            );
          },
        );
      },
    );
  }
}
