import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService(ref.read(apiClientProvider));
});

class UserService {
  final ApiClient _api;

  UserService(this._api);

  /// Block a user
  Future<void> blockUser(String userId) async {
    await _api.post('${ApiEndpoints.blockUser}/$userId');
  }

  /// Unblock a user
  Future<void> unblockUser(String userId) async {
    await _api.delete('${ApiEndpoints.blockUser}/$userId');
  }

  /// Check block status between current user and target user
  /// Returns { blockedByMe: bool, blockedByThem: bool }
  Future<Map<String, dynamic>> checkBlockStatus(String userId) async {
    final response = await _api.get('${ApiEndpoints.blockUser}/$userId/status');
    final data = response.data;
    if (data is Map<String, dynamic>) {
      return data['data'] ?? {};
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data['data'] ?? {});
    }
    return {};
  }
}
