import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../models/call_log.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CallRepository(apiClient);
});

class CallRepository {
  final ApiClient _apiClient;

  CallRepository(this._apiClient);

  Future<List<CallLog>> getCallHistory() async {
    try {
      final response = await _apiClient.get('/calls');

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> data = response.data['data'] ?? [];
        return data.map((json) => CallLog.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching call history: $e');
      return [];
    }
  }

  Future<bool> recordCall({
    String? callerId,
    required String receiverId,
    required String type, // 'audio' or 'video'
    required String status, // 'missed', 'completed', 'declined'
    int duration = 0,
  }) async {
    try {
      final response = await _apiClient.post(
        '/calls',
        data: {
          'callerId': ?callerId,
          'receiverId': receiverId,
          'type': type,
          'status': status,
          'duration': duration,
        },
      );
      return response.statusCode == 201 && response.data['success'] == true;
    } catch (e) {
      print('Error recording call: $e');
      return false;
    }
  }
}
