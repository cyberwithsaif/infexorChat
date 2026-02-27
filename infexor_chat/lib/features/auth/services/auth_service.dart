import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

class AuthService {
  final ApiClient _api;

  AuthService(this._api);

  Future<Map<String, dynamic>> sendOtp({
    required String phone,
    required String countryCode,
  }) async {
    final response = await _api.post(
      ApiEndpoints.sendOtp,
      data: {'phone': phone, 'countryCode': countryCode},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String countryCode,
    required String otp,
    required String reqId, // Added for MSG91 flow
    String? deviceId,
    String? fcmToken,
  }) async {
    final response = await _api.post(
      ApiEndpoints.verifyOtp,
      data: {
        'phone': phone,
        'countryCode': countryCode,
        'otp': otp,
        'reqId': reqId, // Pass reqId
        'deviceId': deviceId ?? 'default',
        'platform': 'android',
        'fcmToken': fcmToken ?? '',
      },
    );
    return response.data;
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final response = await _api.post(
      ApiEndpoints.refreshToken,
      data: {'refreshToken': refreshToken},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _api.get(ApiEndpoints.profile);
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile({
    String? name,
    String? about,
    String? avatar,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (about != null) data['about'] = about;
    if (avatar != null) data['avatar'] = avatar;

    final response = await _api.put(ApiEndpoints.updateProfile, data: data);
    return response.data;
  }

  Future<void> logout({String? deviceId}) async {
    try {
      await _api.post(
        ApiEndpoints.logout,
        data: {'deviceId': deviceId ?? 'default'},
      );
    } on DioException {
      // Ignore errors on logout — clear local state anyway
    }
  }

  Future<void> updateFcmToken(String token, {String? deviceId}) async {
    try {
      await _api.put(
        ApiEndpoints.fcmToken,
        data: {'fcmToken': token, 'deviceId': deviceId ?? 'default'},
      );
    } catch (e) {
      // Background retry logic can be added here if needed
      print("Failed to sync FCM token: $e");
    }
  }
}
