import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../services/chat_service.dart';
import '../services/socket_service.dart';

class MessageState {
  final String chatId;
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const MessageState({
    this.chatId = '',
    this.messages = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  MessageState copyWith({
    String? chatId,
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) {
    return MessageState(
      chatId: chatId ?? this.chatId,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  MessageNotifier.new,
);

class MessageNotifier extends Notifier<MessageState> {
  @override
  MessageState build() => const MessageState();

  /// Open a chat — reset state and load messages
  Future<void> openChat(String chatId) async {
    state = MessageState(chatId: chatId, isLoading: true);

    final socket = ref.read(socketServiceProvider);
    socket.joinChat(chatId);

    // Reset unread count in chat list immediately (UI feedback)
    ref.read(chatListProvider.notifier).markChatRead(chatId);

    try {
      final response = await ref.read(chatServiceProvider).getMessages(chatId);
      final rawMessages = response['data']?['messages'];
      final messages = <Map<String, dynamic>>[];
      if (rawMessages is List) {
        for (final item in rawMessages) {
          if (item is Map) {
            messages.add(Map<String, dynamic>.from(item));
          }
        }
      }
      final hasMore = response['data']?['hasMore'] == true;

      state = state.copyWith(
        messages: messages.reversed.toList(),
        isLoading: false,
        hasMore: hasMore,
      );

      // Mark as read ONLY after messages are loaded and displayed
      // This ensures blue ticks are sent only when user actually sees messages
      if (state.chatId == chatId) {
        socket.markRead(chatId);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Load older messages
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore || state.messages.isEmpty) return;

    state = state.copyWith(isLoading: true);
    try {
      final oldestId = state.messages.last['_id']; // Oldest is at the end
      final response = await ref
          .read(chatServiceProvider)
          .getMessages(state.chatId, before: oldestId);
      final rawOlder = response['data']?['messages'];
      final older = <Map<String, dynamic>>[];
      if (rawOlder is List) {
        for (final item in rawOlder) {
          if (item is Map) {
            older.add(Map<String, dynamic>.from(item));
          }
        }
      }
      final hasMore = response['data']?['hasMore'] == true;

      state = state.copyWith(
        messages: [...state.messages, ...older.reversed], // Append older to end
        isLoading: false,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Send a text message
  void sendMessage(String content, {String? replyTo}) {
    final socket = ref.read(socketServiceProvider);

    socket.sendMessage(
      {
        'chatId': state.chatId,
        'type': 'text',
        'content': content,
        'replyTo': replyTo,
      },
      callback: (response) {
        if (response is Map && response['success'] == true) {
          final msg = Map<String, dynamic>.from(response['message']);
          _addMessage(msg);
          ref.read(chatListProvider.notifier).onNewMessage(msg);
        }
      },
    );
  }

  /// Send a media message (image, video, audio, voice, document, location, contact, gif)
  void sendMediaMessage({
    required String type,
    String content = '',
    Map<String, dynamic>? media,
    Map<String, dynamic>? location,
    Map<String, dynamic>? contactShare,
    String? replyTo,
  }) {
    final socket = ref.read(socketServiceProvider);

    socket.sendMessage(
      {
        'chatId': state.chatId,
        'type': type,
        'content': content,
        'media': media,
        'location': location,
        'contactShare': contactShare,
        'replyTo': replyTo,
      },
      callback: (response) {
        if (response is Map && response['success'] == true) {
          final msg = Map<String, dynamic>.from(response['message']);
          _addMessage(msg);
          ref.read(chatListProvider.notifier).onNewMessage(msg);
        }
      },
    );
  }

  /// Add incoming message
  void addIncomingMessage(Map<String, dynamic> message) {
    if (message['chatId'] == state.chatId && state.chatId.isNotEmpty) {
      _addMessage(message);
      // Mark delivered first
      final msgId = message['_id']?.toString();
      if (msgId != null) {
        ref.read(socketServiceProvider).markDelivered(msgId);
      }
      // Mark as read since user is actively viewing this chat
      ref.read(socketServiceProvider).markRead(state.chatId);
    }
  }

  void _addMessage(Map<String, dynamic> message) {
    final exists = state.messages.any((m) => m['_id'] == message['_id']);
    if (!exists) {
      state = state.copyWith(messages: [message, ...state.messages]);
    }
  }

  static bool _listenersInitialized = false;

  /// Initialize socket listeners for active chat (safe to call multiple times)
  void initSocketListeners() {
    // Only add listeners once — they read state.chatId dynamically,
    // so they work correctly across chat switches via openChat().
    // We can't use socket.off() here because chat_provider also
    // listens on the same events.
    if (_listenersInitialized) return;
    _listenersInitialized = true;

    final socket = ref.read(socketServiceProvider);

    socket.on('message:new', (data) {
      if (data is Map<String, dynamic> && data['chatId'] == state.chatId) {
        addIncomingMessage(data);
      }
    });

    socket.on('message:status', (data) {
      if (data is Map<String, dynamic>) {
        _updateMessageStatus(
          data['messageId']?.toString(),
          data['status']?.toString(),
        );
      }
    });

    socket.on('message:read-ack', (data) {
      if (data is Map<String, dynamic> && data['chatId'] == state.chatId) {
        _markAllAsRead();
      }
    });

    socket.on('message:updated', (data) {
      if (data is Map<String, dynamic> && data['chatId'] == state.chatId) {
        final msg = data['message'];
        if (msg is Map) {
          _updateMessageContent(Map<String, dynamic>.from(msg));
        }
      }
    });

    socket.on('message:deleted', (data) {
      if (data is Map<String, dynamic> && data['chatId'] == state.chatId) {
        final messageId = data['messageId']?.toString();
        final forEveryone = data['forEveryone'] == true;
        if (messageId != null && forEveryone) {
          final messages = [...state.messages];
          final index = messages.indexWhere((m) => m['_id'] == messageId);
          if (index != -1) {
            final msg = Map<String, dynamic>.from(messages[index]);
            msg['type'] = 'revoked';
            msg['content'] = '';
            msg['media'] = null;
            msg['deletedForEveryone'] = true;
            messages[index] = msg;
            state = state.copyWith(messages: messages);
          }
        }
      }
    });

    socket.on('message:reaction', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString();
        final messageId = data['messageId']?.toString();
        final userId = data['userId']?.toString();
        final emoji = data['emoji']?.toString();

        if (chatId == state.chatId &&
            messageId != null &&
            userId != null &&
            emoji != null) {
          final messages = [...state.messages];
          final index = messages.indexWhere((m) => m['_id'] == messageId);
          if (index != -1) {
            final msg = Map<String, dynamic>.from(messages[index]);
            final reactions = List<Map<String, dynamic>>.from(
              msg['reactions'] ?? [],
            );

            // Remove any existing reaction from this user
            reactions.removeWhere(
              (r) => r['user'] == userId || r['userId'] == userId,
            );
            // Add the new reaction
            reactions.add({'emoji': emoji, 'user': userId});

            msg['reactions'] = reactions;
            messages[index] = msg;
            state = state.copyWith(messages: messages);
          }
        }
      }
    });
  }

  /// Clean up when leaving chat
  void closeChat() {
    if (state.chatId.isNotEmpty) {
      // Cancel any pending markRead retries BEFORE leaving
      ref.read(socketServiceProvider).cancelPendingMarkRead();
      ref.read(socketServiceProvider).leaveChat(state.chatId);
      // Reset chatId to '' so incoming messages won't be auto-read
      // Also clear messages to prevent stale state on re-entry
      state = const MessageState();
    }
    // Don't remove socket listeners — they're shared with chat_provider
    // and they check state.chatId dynamically
  }

  void _updateMessageStatus(String? messageId, String? newStatus) {
    if (messageId == null || newStatus == null) return;
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m['_id'] == messageId);
    if (index != -1) {
      messages[index] = {...messages[index], 'status': newStatus};
      state = state.copyWith(messages: messages);
    }
  }

  void _markAllAsRead() {
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';
    final messages = [...state.messages];
    bool changed = false;
    for (int i = 0; i < messages.length; i++) {
      final senderId =
          messages[i]['senderId']?['_id'] ?? messages[i]['senderId'];
      if (senderId == currentUserId && messages[i]['status'] != 'read') {
        messages[i] = {...messages[i], 'status': 'read'};
        changed = true;
      }
    }
    if (changed) {
      state = state.copyWith(messages: messages);
    }
  }

  void _updateMessageContent(Map<String, dynamic>? newMessage) {
    if (newMessage == null) return;
    final id = newMessage['_id'];
    final messages = [...state.messages];
    final index = messages.indexWhere((m) => m['_id'] == id);
    if (index != -1) {
      messages[index] = newMessage;
      state = state.copyWith(messages: messages);
    }
  }

  /// React to a message
  Future<void> reactToMessage(String messageId, String emoji) async {
    try {
      // Optimistically update local message to reflect new reaction instantly
      final index = state.messages.indexWhere((m) => m['_id'] == messageId);
      if (index != -1) {
        final messages = [...state.messages];
        final msg = {...messages[index]};
        final reactions = List<Map<String, dynamic>>.from(
          msg['reactions'] ?? [],
        );

        // Remove existing reaction if toggling off
        final currentUserId = ref.read(authProvider).user?['_id'];
        final existingIndex = reactions.indexWhere(
          (r) => r['user'] == currentUserId,
        );

        if (existingIndex != -1 && reactions[existingIndex]['emoji'] == emoji) {
          reactions.removeAt(existingIndex);
        } else {
          if (existingIndex != -1) reactions.removeAt(existingIndex);
          reactions.add({'emoji': emoji, 'user': currentUserId});
        }

        msg['reactions'] = reactions;
        messages[index] = msg;
        state = state.copyWith(messages: messages);
      }

      await ref
          .read(chatServiceProvider)
          .reactToMessage(state.chatId, messageId, emoji);
    } catch (e) {
      // In a real app, revert the optimistic update here if the API fails
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String messageId, bool forEveryone) async {
    try {
      await ref
          .read(chatServiceProvider)
          .deleteMessage(state.chatId, messageId, forEveryone);

      if (forEveryone) {
        final messages = [...state.messages];
        final index = messages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          final msg = Map<String, dynamic>.from(messages[index]);
          msg['type'] = 'revoked';
          msg['content'] = '';
          msg['media'] = null;
          msg['deletedForEveryone'] = true;
          messages[index] = msg;
          state = state.copyWith(messages: messages);
        }
      } else {
        // Remove the message from local state (for 'delete for me')
        final messages = state.messages
            .where((m) => m['_id'] != messageId)
            .toList();
        state = state.copyWith(messages: messages);
      }
    } catch (e) {
      // throw to let UI handle error
      rethrow;
    }
  }
}
