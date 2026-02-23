import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_endpoints.dart';

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class SocketService {
  io.Socket? _socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  io.Socket? get socket => _socket;

  // Single source of truth for event handlers
  final Map<String, List<Function(dynamic)>> _pendingListeners = {};

  /// Connect to Socket.io server with JWT token
  void connect(String token) {
    if (_isConnected) return;

    // Base URL without /api path
    final baseUrl = ApiEndpoints.baseUrl.replaceAll('/api', '');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(10)
          .setReconnectionDelay(2000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      print('[SocketService] ✅ Connected! socket.id=${_socket?.id}');
      // Re-attach all managed listeners — clear first to avoid duplicates
      _reattachAllListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
    });

    _socket!.onConnectError((error) {
      _isConnected = false;
      print('[SocketService] ❌ Connect error: $error');
    });
  }

  /// Clear and re-register all managed event listeners on the socket.
  /// This is the ONLY place listeners are attached to the socket,
  /// guaranteeing exactly one registration per handler.
  void _reattachAllListeners() {
    _pendingListeners.forEach((event, handlers) {
      _socket!.off(event); // remove any existing handlers for this event
      for (final handler in handlers) {
        _socket!.on(event, handler);
      }
    });
  }

  /// Disconnect
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  /// Send a message
  void sendMessage(Map<String, dynamic> data, {Function(dynamic)? callback}) {
    print(
      '[SocketService] sendMessage called. isConnected=$_isConnected, socket=${_socket != null}, data=$data',
    );
    if (_socket == null) {
      print('[SocketService] ⚠️ Socket is null! Message NOT sent.');
      return;
    }
    _socket?.emitWithAck(
      'message:send',
      data,
      ack: (response) {
        print('[SocketService] 📨 Ack received: $response');
        callback?.call(response);
      },
    );
  }

  /// Mark messages as delivered
  void markDelivered(String messageId) {
    _socket?.emit('message:delivered', {'messageId': messageId});
  }

  /// Track which chatId has a pending markRead retry
  String? _pendingMarkReadChatId;

  /// Mark chat as read — with retry if socket not connected yet
  void markRead(String chatId) {
    _pendingMarkReadChatId = chatId;
    if (_isConnected && _socket != null) {
      _socket!.emit('message:read', {'chatId': chatId});
      _pendingMarkReadChatId = null;
    } else {
      // Retry up to 3 times with 500ms delay
      _retryMarkRead(chatId, 3);
    }
  }

  /// Cancel any pending markRead retries (call when user leaves a chat)
  void cancelPendingMarkRead() {
    _pendingMarkReadChatId = null;
  }

  void _retryMarkRead(String chatId, int attemptsLeft) {
    if (attemptsLeft <= 0) return;
    Future.delayed(const Duration(milliseconds: 500), () {
      // If user already left this chat, don't emit
      if (_pendingMarkReadChatId != chatId) return;
      if (_isConnected && _socket != null) {
        _socket!.emit('message:read', {'chatId': chatId});
        _pendingMarkReadChatId = null;
      } else {
        _retryMarkRead(chatId, attemptsLeft - 1);
      }
    });
  }

  /// Typing indicators
  void startTyping(String chatId) {
    _socket?.emit('typing:start', {'chatId': chatId});
  }

  void stopTyping(String chatId) {
    _socket?.emit('typing:stop', {'chatId': chatId});
  }

  /// Join/leave chat room
  void joinChat(String chatId) {
    _socket?.emit('chat:join', {'chatId': chatId});
  }

  void leaveChat(String chatId) {
    _socket?.emit('chat:leave', {'chatId': chatId});
  }

  /// Listen to events.
  /// Handlers are stored in _pendingListeners and attached via
  /// _reattachAllListeners() on (re)connect. If already connected,
  /// we clear + re-attach immediately so the new handler takes effect.
  void on(String event, Function(dynamic) handler) {
    // Add to the pending buffer (single source of truth)
    if (!_pendingListeners.containsKey(event)) {
      _pendingListeners[event] = [];
    }
    _pendingListeners[event]!.add(handler);

    // If already connected, clear + re-attach for this event immediately
    if (_isConnected && _socket != null) {
      _socket!.off(event);
      for (final h in _pendingListeners[event]!) {
        _socket!.on(event, h);
      }
    }
  }

  /// Remove all listeners for an event
  void off(String event) {
    _socket?.off(event);
    _pendingListeners.remove(event);
  }
}
