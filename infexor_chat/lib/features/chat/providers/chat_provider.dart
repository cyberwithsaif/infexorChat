import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ChatListState {
  final List<Map<String, dynamic>> chats;
  final bool isLoading;
  final String? error;

  const ChatListState({
    this.chats = const [],
    this.isLoading = false,
    this.error,
  });

  ChatListState copyWith({
    List<Map<String, dynamic>>? chats,
    bool? isLoading,
    String? error,
  }) {
    return ChatListState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final chatListProvider = NotifierProvider<ChatListNotifier, ChatListState>(
  ChatListNotifier.new,
);

class ChatListNotifier extends Notifier<ChatListState> {
  static const _cacheBoxName = 'chat_list_cache';
  static const _cacheKey = 'chats_json';

  @override
  ChatListState build() => const ChatListState();

  /// Load chats: show local cache instantly, then refresh from server
  Future<void> loadChats() async {
    // 1. If state is empty, load from local cache first (instant / offline)
    if (state.chats.isEmpty) {
      final cached = await _loadFromCache();
      if (cached.isNotEmpty) {
        state = state.copyWith(chats: cached, isLoading: true, error: null);
      } else {
        state = state.copyWith(isLoading: true, error: null);
      }
    } else {
      state = state.copyWith(isLoading: true, error: null);
    }

    // 2. Fetch from server
    try {
      final response = await ref.read(chatServiceProvider).getChats();
      final rawChats = response['data']?['chats'];
      final chats = <Map<String, dynamic>>[];
      if (rawChats is List) {
        for (final item in rawChats) {
          if (item is Map) {
            final lastMsg = item['lastMessage'];
            if (lastMsg != null && lastMsg is Map) {
              chats.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      // Sort by lastMessageAt descending — latest chat first
      chats.sort((a, b) {
        final aTime = a['lastMessageAt']?.toString() ?? '';
        final bTime = b['lastMessageAt']?.toString() ?? '';
        return bTime.compareTo(aTime);
      });

      state = state.copyWith(chats: chats, isLoading: false);
      _cacheChatParticipants(chats);
      _saveToCache(chats);
    } catch (e) {
      debugPrint('❌ loadChats error: $e');
      // If we already have chats (from cache or previous load), keep them visible
      if (state.chats.isNotEmpty) {
        state = state.copyWith(isLoading: false, error: null);
      } else {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  /// Save chat list to local Hive cache
  Future<void> _saveToCache(List<Map<String, dynamic>> chats) async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final jsonStr = jsonEncode(chats);
      await box.put(_cacheKey, jsonStr);
    } catch (e) {
      debugPrint('⚠️ Failed to cache chats: $e');
    }
  }

  /// Load chat list from local Hive cache
  Future<List<Map<String, dynamic>>> _loadFromCache() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final jsonStr = box.get(_cacheKey);
      if (jsonStr is String && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to read chat cache: $e');
    }
    return [];
  }

  /// Create a new chat and add to list
  Future<Map<String, dynamic>?> createChat(String participantId) async {
    try {
      final response = await ref
          .read(chatServiceProvider)
          .createChat(participantId);
      final chat = response['data']?['chat'] as Map<String, dynamic>?;
      if (chat != null) {
        // Do not add to state immediately.
        // Wait for first message to be sent/received.
      }
      return chat;
    } catch (e) {
      return null;
    }
  }

  /// Update chat with new message (called from socket events)
  void onNewMessage(Map<String, dynamic> message) {
    final rawChatId = message['chatId'];
    final chatId = rawChatId is Map
        ? rawChatId['_id']?.toString()
        : rawChatId?.toString();
    final chats = [...state.chats];
    final index = chats.indexWhere((c) => c['_id']?.toString() == chatId);

    final currentUserId = ref.read(authProvider).user?['_id'];
    final sender = message['senderId'];
    final senderId = sender is Map ? sender['_id'] : sender;
    final isOutgoing = currentUserId != null && senderId == currentUserId;

    // Check if user is currently viewing this chat
    final activeChatIdStr = ref
        .read(notificationServiceProvider)
        .activeChatId
        ?.toString();
    final isViewingChat = activeChatIdStr != null && activeChatIdStr == chatId;

    if (index != -1) {
      final chat = Map<String, dynamic>.from(chats[index]);
      chat['lastMessage'] = message;
      chat['lastMessageAt'] =
          message['createdAt'] ?? DateTime.now().toUtc().toIso8601String();
      if (!isOutgoing && !isViewingChat) {
        chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;
      }
      // Move to top (latest chat first like WhatsApp)
      chats.removeAt(index);
      chats.insert(0, chat);
      state = state.copyWith(chats: chats);
      _saveToCache(chats);
    } else {
      // New chat not in list yet — reload from server
      loadChats();
    }
  }

  static bool _listenersInitialized = false;

  /// Initialize socket listeners for chat list updates (called once)
  void initSocketListeners() {
    if (_listenersInitialized) return;
    _listenersInitialized = true;

    final socket = ref.read(socketServiceProvider);
    final notifService = ref.read(notificationServiceProvider);

    socket.on('message:new', (data) {
      if (data is Map<String, dynamic>) {
        onNewMessage(data);

        final currentUserId = ref.read(authProvider).user?['_id'];
        final currentSender = data['senderId'];
        final currentSenderId = currentSender is Map
            ? currentSender['_id']
            : currentSender;
        final isOutgoing =
            currentUserId != null && currentSenderId == currentUserId;

        if (isOutgoing) {
          return; // Skip notifications and ACKs for outgoing messages
        }

        // Mark as delivered
        final messageId = data['_id']?.toString();
        if (messageId != null) {
          socket.markDelivered(messageId);
        }

        // Show local notification
        final sender = data['senderId'];
        final senderId = sender is Map
            ? sender['_id']?.toString()
            : (sender is String ? sender : null);

        // Try device-saved contact name first, then server name, then phone number
        String senderName = 'Someone';
        if (senderId != null) {
          try {
            // 1. Check device contacts cache (saved in phone)
            if (Hive.isBoxOpen('contacts_cache')) {
              final savedName = Hive.box('contacts_cache').get(senderId);
              if (savedName != null && savedName.toString().isNotEmpty) {
                senderName = savedName.toString();
              } else if (sender is Map) {
                // 2. Use phone number for unsaved contacts, fallback to registered name
                final phone = sender['phone']?.toString();
                final name = sender['name']?.toString();
                senderName = PhoneUtils.formatPhoneDisplay(phone).isNotEmpty
                    ? PhoneUtils.formatPhoneDisplay(phone)
                    : name ?? 'Someone';
              }
            } else if (sender is Map) {
              final phone = sender['phone']?.toString();
              final name = sender['name']?.toString();
              senderName = PhoneUtils.formatPhoneDisplay(phone).isNotEmpty
                  ? PhoneUtils.formatPhoneDisplay(phone)
                  : name ?? 'Someone';
            }
          } catch (_) {
            if (sender is Map) {
              senderName =
                  sender['phone']?.toString() ??
                  sender['name']?.toString() ??
                  'Someone';
            }
          }
        } else if (sender is Map) {
          senderName =
              sender['phone']?.toString() ??
              sender['name']?.toString() ??
              'Someone';
        }

        // Cache sender name for background service notifications
        if (sender is Map) {
          _cacheSingleUser(Map<String, dynamic>.from(sender));
        }

        // Build message content for notification
        final msgType = data['type']?.toString() ?? 'text';
        String msgContent;
        if (msgType == 'text') {
          msgContent = data['content']?.toString() ?? 'Sent a message';
        } else if (msgType == 'image') {
          msgContent = '📷 Photo';
        } else if (msgType == 'video') {
          msgContent = '🎥 Video';
        } else if (msgType == 'voice' || msgType == 'audio') {
          msgContent = '🎤 Voice message';
        } else if (msgType == 'document') {
          msgContent = '📄 Document';
        } else if (msgType == 'location') {
          msgContent = '📍 Location';
        } else if (msgType == 'gif') {
          msgContent = 'GIF';
        } else {
          msgContent = data['content']?.toString() ?? 'Sent a message';
        }

        final chatId = data['chatId']?.toString() ?? '';
        notifService.showMessageNotification(
          chatId: chatId,
          senderName: senderName,
          messageContent: msgContent,
        );
      }
    });

    socket.on('message:deleted', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString();
        final messageId = data['messageId']?.toString();
        final forEveryone = data['forEveryone'] == true;

        if (chatId != null && messageId != null && forEveryone) {
          final chats = [...state.chats];
          final index = chats.indexWhere((c) => c['_id'] == chatId);
          if (index != -1) {
            final lastMsg = chats[index]['lastMessage'];
            if (lastMsg is Map && lastMsg['_id']?.toString() == messageId) {
              chats[index] = {
                ...chats[index],
                'lastMessage': {
                  ...lastMsg,
                  'type': 'revoked',
                  'content': '',
                  'media': null,
                  'deletedForEveryone': true,
                },
              };
              state = state.copyWith(chats: chats);
            }
          }
        }
      }
    });

    // Listen for status updates to refresh ticks in chat list
    socket.on('message:status', (data) {
      if (data is Map<String, dynamic>) {
        _updateChatMessageStatus(data);
      }
    });

    socket.on('message:read-ack', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString();
        if (chatId != null) {
          _markChatLastMessageRead(chatId);
        }
      }
    });

    // Listen for user online status — backend emits 'presence:online'/'presence:offline'
    socket.on('presence:online', (data) {
      if (data is Map) {
        final userId = data['userId'] ?? data['_id'];
        _updateUserStatus(userId?.toString(), true);
      }
    });

    socket.on('presence:offline', (data) {
      if (data is Map) {
        final userId = data['userId'] ?? data['_id'];
        _updateUserStatus(userId?.toString(), false);
      }
    });
  }

  /// Reset unread count for a specific chat (called when user opens the chat)
  void markChatRead(String chatId) {
    final chats = [...state.chats];
    final index = chats.indexWhere((c) => c['_id']?.toString() == chatId);
    if (index != -1) {
      chats[index] = {...chats[index], 'unreadCount': 0};
      state = state.copyWith(chats: chats);
    }
  }

  /// Update the last message status in chat list for tick display
  void _updateChatMessageStatus(Map<String, dynamic> data) {
    final messageId = data['messageId']?.toString();
    final newStatus = data['status']?.toString();
    if (messageId == null || newStatus == null) return;

    final chats = [...state.chats];
    final index = chats.indexWhere((c) {
      final lastMsg = c['lastMessage'];
      return lastMsg is Map && lastMsg['_id']?.toString() == messageId;
    });
    if (index != -1) {
      final lastMsg = chats[index]['lastMessage'];
      chats[index] = {
        ...chats[index],
        'lastMessage': {...(lastMsg as Map), 'status': newStatus},
      };
      state = state.copyWith(chats: chats);
    }
  }

  /// Mark last message as read for a given chat
  void _markChatLastMessageRead(String chatId) {
    final chats = [...state.chats];
    final index = chats.indexWhere((c) => c['_id']?.toString() == chatId);
    if (index != -1) {
      final lastMsg = chats[index]['lastMessage'];
      if (lastMsg is Map) {
        chats[index] = {
          ...chats[index],
          'lastMessage': {...lastMsg, 'status': 'read'},
          'unreadCount': 0,
        };
      }
      state = state.copyWith(chats: chats);
    }
  }

  /// Update user online status
  void _updateUserStatus(String? userId, bool isOnline) {
    if (userId == null) return;

    final chats = [...state.chats];
    bool changed = false;
    for (int i = 0; i < chats.length; i++) {
      final rawParticipants = chats[i]['participants'];
      if (rawParticipants is List) {
        final hasUser = rawParticipants.any(
          (p) => p is Map && p['_id'] == userId,
        );
        if (hasUser) {
          final participants = rawParticipants.map((p) {
            if (p is Map && p['_id'] == userId) {
              final updated = {...p, 'isOnline': isOnline};
              if (!isOnline) {
                updated['lastSeen'] = DateTime.now().toUtc().toIso8601String();
              }
              return updated;
            }
            return p;
          }).toList();
          chats[i] = {...chats[i], 'participants': participants};
          changed = true;
        }
      }
    }
    if (changed) {
      state = state.copyWith(chats: chats);
    }
  }

  /// Cache server names for background notification display (separate from device contacts)
  Future<void> _cacheChatParticipants(List<Map<String, dynamic>> chats) async {
    try {
      final box = await Hive.openBox('server_names');
      final nameMap = <String, String>{};

      for (final chat in chats) {
        final participants = chat['participants'];
        if (participants is List) {
          for (final p in participants) {
            if (p is Map) {
              final id = p['_id']?.toString();
              final name = p['name']?.toString();
              if (id != null && name != null && name != 'Unknown') {
                nameMap[id] = name;
              }
            }
          }
        }
      }
      if (nameMap.isNotEmpty) {
        box.putAll(nameMap);
      }
    } catch (_) {}
  }

  /// Cache single user server name for notifications
  Future<void> _cacheSingleUser(Map<String, dynamic> user) async {
    try {
      final id = user['_id']?.toString();
      final name = user['name']?.toString();
      if (id != null && name != null && name != 'Unknown') {
        final box = await Hive.openBox('server_names');
        box.put(id, name);
      }
    } catch (_) {}
  }
}
