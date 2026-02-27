import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../config/routes.dart';
import '../../../core/network/api_client.dart';
import '../services/auth_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  profileSetup,
}

class AuthState {
  final AuthStatus status;
  final String? accessToken;
  final String? refreshToken;
  final String? reqId; // Added for MSG91 flow
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.accessToken,
    this.refreshToken,
    this.reqId,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? accessToken,
    String? refreshToken,
    String? reqId,
    Map<String, dynamic>? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      reqId: reqId ?? this.reqId,
      user: user ?? this.user,
      error: error,
    );
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  static const _boxName = 'auth';

  @override
  AuthState build() => const AuthState();

  /// Check if user is already logged in
  Future<void> checkAuth() async {
    final box = await Hive.openBox(_boxName);
    final token = box.get('accessToken');
    final refresh = box.get('refreshToken');
    final isProfileComplete = box.get('isProfileComplete', defaultValue: false);
    final user = box.get('user') != null
        ? Map<String, dynamic>.from(box.get('user'))
        : null;

    state = const AuthState(status: AuthStatus.unauthenticated);
    if (token != null && token.toString().isNotEmpty) {
      ref.read(apiClientProvider).setToken(token);

      // Determine correct status from persisted flag
      final restoredStatus = isProfileComplete
          ? AuthStatus.authenticated
          : AuthStatus.profileSetup;

      // Restore cached user first to avoid loading screens
      if (user != null) {
        state = AuthState(
          status: restoredStatus,
          accessToken: token,
          refreshToken: refresh,
          user: user,
        );
      } else {
        // Token exists but user not cached — set status so splash routes correctly
        state = AuthState(
          status: restoredStatus,
          accessToken: token,
          refreshToken: refresh,
        );
      }

      // Fetch and sync FCM token on every app startup
      try {
        print("======== STARTING FCM TOKEN FETCH ========");
        final messaging = FirebaseMessaging.instance;
        print("======== REQUESTING PERMISSION ========");
        await messaging.requestPermission();
        print("======== GETTING TOKEN ========");
        final fcmToken = await messaging.getToken();
        print("======== TOKEN RECEIVED: $fcmToken ========");
        if (fcmToken != null) {
          ref.read(authServiceProvider).updateFcmToken(fcmToken);
          print("======== TOKEN SENT TO BACKEND ========");
        }
      } catch (e) {
        print("======== FAILED TO SYNC FCM TOKEN ON STARTUP: $e ========");
      }

      try {
        final profileRes = await ref.read(authServiceProvider).getProfile();
        final freshUser = profileRes['data']?['user'];
        if (freshUser != null) {
          await box.put('user', freshUser);
          state = state.copyWith(user: freshUser);
        }
      } catch (_) {
        // Keep cached user if fetch fails
      }
    }
  }

  /// Send OTP to phone
  Future<bool> sendOtp({
    required String phone,
    required String countryCode,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await ref
          .read(authServiceProvider)
          .sendOtp(phone: phone, countryCode: countryCode);

      // Store reqId in state
      final reqId = response['data']['reqId'];

      state = state.copyWith(status: AuthStatus.unauthenticated, reqId: reqId);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
      return false;
    }
  }

  /// Verify OTP and complete login
  Future<bool> verifyOtp({
    required String phone,
    required String countryCode,
    required String otp,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      // Use stored reqId
      if (state.reqId == null) {
        throw Exception('Request ID missing. Please resend OTP.');
      }

      // Request FCM permissions and get token
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      String? fcmToken;
      try {
        fcmToken = await messaging.getToken();
        print("FCM Token: $fcmToken");
      } catch (e) {
        print("Failed to get FCM token: $e");
      }

      final response = await ref
          .read(authServiceProvider)
          .verifyOtp(
            phone: phone,
            countryCode: countryCode,
            otp: otp,
            reqId: state.reqId!, // Pass reqId
            fcmToken: fcmToken,
          );

      final data = response['data'];
      final accessToken = data['accessToken'];
      final refreshToken = data['refreshToken'];
      final isProfileComplete = data['isProfileComplete'] ?? false;
      final user = data['user'];

      // Save tokens and user
      final box = await Hive.openBox(_boxName);
      await box.put('accessToken', accessToken);
      await box.put('refreshToken', refreshToken);
      await box.put('isProfileComplete', isProfileComplete);
      if (user != null) {
        await box.put('user', Map<String, dynamic>.from(user));
      }

      // Set token on API client
      ref.read(apiClientProvider).setToken(accessToken);

      if (!isProfileComplete) {
        state = AuthState(
          status: AuthStatus.profileSetup,
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );
      } else {
        state = AuthState(
          status: AuthStatus.authenticated,
          accessToken: accessToken,
          refreshToken: refreshToken,
          user: user,
        );
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
      return false;
    }
  }

  /// Update profile (name, about, avatar)
  Future<bool> updateProfile({
    String? name,
    String? about,
    String? avatar,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await ref
          .read(authServiceProvider)
          .updateProfile(name: name, about: about, avatar: avatar);

      final userData = response['data']?['user'] ?? response['user'];

      if (userData != null) {
        final box = await Hive.openBox(_boxName);

        // Merge with existing user data to not lose fields
        final currentUser = box.get('user');
        final Map<String, dynamic> newUser = currentUser != null
            ? Map<String, dynamic>.from(currentUser)
            : {};

        if (name != null) newUser['name'] = name;
        if (about != null) newUser['about'] = about;
        if (avatar != null) newUser['avatar'] = avatar;

        // Also merge any other fields from backend response
        newUser.addAll(Map<String, dynamic>.from(userData));

        await box.put('user', newUser);
        await box.put('isProfileComplete', true);

        state = state.copyWith(status: AuthStatus.authenticated, user: newUser);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.authenticated, // Revert to authenticated
        error: _extractError(e),
      );
      return false;
    }
  }

  /// Complete profile setup (alias for updateProfile)
  Future<bool> completeProfile({
    required String name,
    String? about,
    String? avatar,
  }) async {
    return updateProfile(name: name, about: about, avatar: avatar);
  }

  /// Update user data locally (in state + Hive cache) without server call
  Future<void> updateUserLocally(Map<String, dynamic> updatedUser) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put('user', updatedUser);
      state = state.copyWith(user: updatedUser);
    } catch (_) {}
  }

  /// Logout
  Future<void> logout() async {
    try {
      await ref.read(authServiceProvider).logout();
    } catch (_) {
      // Ignore server errors during logout (e.g. 401 on expired token)
    }
    ref.read(apiClientProvider).clearToken();

    final box = await Hive.openBox(_boxName);
    await box.clear();

    state = const AuthState(status: AuthStatus.unauthenticated);

    // Navigate to login screen
    final ctx = navigatorKey.currentContext;
    if (ctx != null) {
      GoRouter.of(ctx).go('/login');
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timeout. Please try again.';
      }
      return 'Invalid OTP or Network Error';
    }
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'Something went wrong';
  }
}
