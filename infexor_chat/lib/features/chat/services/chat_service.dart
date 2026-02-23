import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(ref.read(apiClientProvider));
});

class ChatService {
  final ApiClient _api;

  ChatService(this._api);

  /// Safely parse response data — handles both Map and raw JSON String
  Map<String, dynamic> _parseResponse(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  /// Create or get existing 1:1 chat
  Future<Map<String, dynamic>> createChat(String participantId) async {
    final response = await _api.post(
      ApiEndpoints.createChat,
      data: {'participantId': participantId},
    );
    return _parseResponse(response.data);
  }

  /// Get user's chats
  Future<Map<String, dynamic>> getChats({int page = 1, int limit = 30}) async {
    final response = await _api.get(
      ApiEndpoints.chats,
      queryParams: {'page': page.toString(), 'limit': limit.toString()},
    );
    return _parseResponse(response.data);
  }

  /// Get messages for a chat
  Future<Map<String, dynamic>> getMessages(
    String chatId, {
    String? before,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{'limit': limit.toString()};
    if (before != null) params['before'] = before;

    final response = await _api.get(
      '${ApiEndpoints.chats}/$chatId/messages',
      queryParams: params,
    );
    return _parseResponse(response.data);
  }

  /// Search messages in a chat
  Future<Map<String, dynamic>> searchMessages(
    String chatId,
    String query,
  ) async {
    final response = await _api.get(
      '${ApiEndpoints.chats}/$chatId/messages/search',
      queryParams: {'q': query},
    );
    return _parseResponse(response.data);
  }

  /// Delete a message
  Future<void> deleteMessage(
    String chatId,
    String messageId,
    bool forEveryone,
  ) async {
    await _api.delete(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId',
      data: {'forEveryone': forEveryone},
    );
  }

  /// React to a message
  Future<void> reactToMessage(
    String chatId,
    String messageId,
    String emoji,
  ) async {
    await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/react',
      data: {'emoji': emoji},
    );
  }

  /// Star/unstar a message
  Future<Map<String, dynamic>> starMessage(
    String chatId,
    String messageId,
  ) async {
    final response = await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/star',
    );
    return _parseResponse(response.data);
  }

  /// Forward a message
  Future<void> forwardMessage(
    String chatId,
    String messageId,
    String targetChatId,
  ) async {
    await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/forward',
      data: {'targetChatId': targetChatId},
    );
  }

  /// Get starred messages
  Future<Map<String, dynamic>> getStarredMessages() async {
    final response = await _api.get('${ApiEndpoints.chats}/starred');
    return response.data;
  }

  /// Get all media for current user
  Future<Map<String, dynamic>> getAllMedia({
    int page = 1,
    int limit = 30,
  }) async {
    final response = await _api.get(
      ApiEndpoints.allMedia,
      queryParams: {'page': page.toString(), 'limit': limit.toString()},
    );
    return _parseResponse(response.data);
  }
}
