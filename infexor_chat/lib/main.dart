import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_strings.dart';
import 'core/services/background_service.dart';
import 'config/routes.dart';

import 'core/services/call_manager.dart';
import 'core/widgets/active_call_banner.dart';
import 'core/widgets/active_call_pip.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Background Service
  await initializeBackgroundService();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('messages_cache');

  // Lock to portrait mode
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0F),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: InfexorChatApp()));
}

class InfexorChatApp extends ConsumerStatefulWidget {
  const InfexorChatApp({super.key});

  @override
  ConsumerState<InfexorChatApp> createState() => _InfexorChatAppState();
}

class _InfexorChatAppState extends ConsumerState<InfexorChatApp> {
  @override
  void initState() {
    super.initState();
    // Initialize Call Manager to listen for incoming calls
    // We delay slightly to ensure providers are ready? No, initState is fine.
    // However, socket might not be connected until login.
    // CallManager logic handles checking socket connectivity or it relies on socket service.
    // Since socket connects in Auth/Home, we just register listener once.

    // Better: We should probably init this after login.
    // But initializing it here is safe as long as we don't crash if socket is null.
    // socketServiceProvider lazily creates SocketService.

    // Actually, socket connects in background_service or home.
    // Let's just init it.
    Future.microtask(() {
      ref.read(callManagerProvider).init();
    });
  }

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
                // Floating PiP for active video calls
                const ActiveCallPip(),
              ],
            );
          },
        );
      },
    );
  }
}
