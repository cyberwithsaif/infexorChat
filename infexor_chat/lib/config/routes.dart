import 'package:go_router/go_router.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/profile_setup_screen.dart';
import '../features/contacts/screens/contacts_screen.dart';
import '../features/chat/screens/conversation_screen.dart';
import '../features/home/home_screen.dart';

import 'package:flutter/material.dart';

final navigatorKey = GlobalKey<NavigatorState>();

/// Slide + fade transition helper for GoRouter pages.
CustomTransitionPage _slideFadePage({
  required LocalKey key,
  required Widget child,
  Offset beginOffset = const Offset(1.0, 0.0),
  Duration duration = const Duration(milliseconds: 350),
  Duration reverseDuration = const Duration(milliseconds: 300),
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
            .animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

/// Fade-only transition helper for GoRouter pages.
CustomTransitionPage _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

final router = GoRouter(
  navigatorKey: navigatorKey,
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const SplashScreen(),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _fadePage(
        key: state.pageKey,
        child: const LoginScreen(),
      ),
    ),
    GoRoute(
      path: '/otp',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return _slideFadePage(
          key: state.pageKey,
          child: OtpScreen(
            phone: extra['phone'] as String,
            countryCode: extra['countryCode'] as String,
          ),
        );
      },
    ),
    GoRoute(
      path: '/profile-setup',
      pageBuilder: (context, state) => _slideFadePage(
        key: state.pageKey,
        child: const ProfileSetupScreen(),
      ),
    ),
    GoRoute(
      path: '/home',
      pageBuilder: (context, state) => _fadePage(
        key: state.pageKey,
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/contacts',
      pageBuilder: (context, state) => _slideFadePage(
        key: state.pageKey,
        child: const ContactsScreen(),
        beginOffset: const Offset(0.0, 1.0), // slide up
      ),
    ),
    GoRoute(
      path: '/chat/:chatId',
      pageBuilder: (context, state) {
        final chatId = state.pathParameters['chatId']!;
        final extra = (state.extra as Map<String, dynamic>?) ?? {};
        return _slideFadePage(
          key: state.pageKey,
          child: ConversationScreen(
            chatId: chatId,
            chatName: extra['chatName'] as String? ?? 'Chat',
            chatAvatar: extra['chatAvatar'] as String? ?? '',
            isOnline: extra['isOnline'] as bool? ?? false,
          ),
        );
      },
    ),
  ],
);
