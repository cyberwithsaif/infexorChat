import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final statusServiceProvider = Provider<StatusService>((ref) {
  return StatusService(ref.read(apiClientProvider));
});

class StatusService {
  final ApiClient _api;

  StatusService(this._api);

  /// Create a text status
  Future<Map<String, dynamic>> createTextStatus({
    required String content,
    String backgroundColor = '#075E54',
  }) async {
    final response = await _api.post(
      ApiEndpoints.status,
      data: {
        'type': 'text',
        'content': content,
        'backgroundColor': backgroundColor,
      },
    );
    return _parse(response.data);
  }

  /// Create an image status
  Future<Map<String, dynamic>> createImageStatus({
    required Map<String, dynamic> media,
    String caption = '',
  }) async {
    final response = await _api.post(
      ApiEndpoints.status,
      data: {'type': 'image', 'content': caption, 'media': media},
    );
    return _parse(response.data);
  }

  /// Get my own statuses
  Future<Map<String, dynamic>> getMyStatuses() async {
    final response = await _api.get(ApiEndpoints.myStatuses);
    return _parse(response.data);
  }

  /// Get contacts' statuses
  Future<Map<String, dynamic>> getContactStatuses() async {
    final response = await _api.get(ApiEndpoints.contactStatuses);
    return _parse(response.data);
  }

  /// Mark a status as viewed
  Future<void> viewStatus(String statusId) async {
    await _api.post('${ApiEndpoints.status}/$statusId/view');
  }

  /// Delete own status
  Future<void> deleteStatus(String statusId) async {
    await _api.delete('${ApiEndpoints.status}/$statusId');
  }

  Map<String, dynamic> _parse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }
}
