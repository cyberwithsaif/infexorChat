import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Check auth immediately without any delay
    Future.microtask(() => _checkAuthAndNavigate());
  }

  Future<void> _checkAuthAndNavigate() async {
    await ref.read(authProvider.notifier).checkAuth();
    if (!mounted) return;

    final status = ref.read(authProvider).status;

    switch (status) {
      case AuthStatus.authenticated:
        context.go('/home');
        break;
      case AuthStatus.profileSetup:
        context.go('/profile-setup');
        break;
      default:
        context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a plain white screen matching the native launch background
    // to make the transition seamless and instant.
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      ),
    );
  }
}
