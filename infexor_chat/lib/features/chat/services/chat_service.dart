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
      '${ApiEndpoints.chats}/$chatId/messages/$messageId?forEveryone=$forEveryone',
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

  /// Edit a text message (sender only, within the server's 15-min window)
  Future<void> editMessage(
    String chatId,
    String messageId,
    String content,
  ) async {
    await _api.put(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId',
      data: {'content': content},
    );
  }

  /// Pin / unpin a message for the whole chat. Returns the new pinned state.
  Future<bool> pinMessage(String chatId, String messageId) async {
    final res = await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/pin',
    );
    final data = res.data is Map ? res.data['data'] : null;
    return (data is Map ? data['isPinned'] == true : false);
  }

  /// Cast / retract a vote on a poll message.
  Future<void> votePoll(String chatId, String messageId, int optionIndex) async {
    await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/vote',
      data: {'optionIndex': optionIndex},
    );
  }

  /// Mark a view-once message as viewed (server scrubs its media).
  Future<void> markViewOnceViewed(String chatId, String messageId) async {
    await _api.post(
      '${ApiEndpoints.chats}/$chatId/messages/$messageId/viewed',
    );
  }

  /// Set disappearing-messages duration for a chat (seconds; 0 = off).
  Future<void> setDisappearing(String chatId, int durationSeconds) async {
    await _api.post(
      '${ApiEndpoints.chats}/$chatId/disappearing',
      data: {'duration': durationSeconds},
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

  /// Pin/unpin a chat
  Future<void> pinChat(String chatId) async {
    await _api.post('${ApiEndpoints.chats}/$chatId/pin');
  }

  /// Mute/unmute a chat
  Future<void> muteChat(String chatId) async {
    await _api.post('${ApiEndpoints.chats}/$chatId/mute');
  }

  /// Archive/unarchive a chat
  Future<void> archiveChat(String chatId) async {
    await _api.post('${ApiEndpoints.chats}/$chatId/archive');
  }

  /// Mark a chat as read
  Future<void> markAsRead(String chatId) async {
    await _api.post('${ApiEndpoints.chats}/$chatId/mark-read');
  }

  /// Mark a chat as unread
  Future<void> markAsUnread(String chatId) async {
    await _api.post('${ApiEndpoints.chats}/$chatId/mark-unread');
  }

  /// Delete a chat
  Future<void> deleteChat(String chatId) async {
    await _api.delete('${ApiEndpoints.chats}/$chatId');
  }
}
