import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/socket_service.dart';

class PresenceState {
  final Map<String, bool> onlineUsers; // userId -> isOnline
  final Map<String, DateTime> lastSeen; // userId -> lastSeen
  final Map<String, String> typingUsers; // chatId -> userId who is typing
  final Map<String, String> recordingUsers; // chatId -> userId who is recording

  const PresenceState({
    this.onlineUsers = const {},
    this.lastSeen = const {},
    this.typingUsers = const {},
    this.recordingUsers = const {},
  });

  PresenceState copyWith({
    Map<String, bool>? onlineUsers,
    Map<String, DateTime>? lastSeen,
    Map<String, String>? typingUsers,
    Map<String, String>? recordingUsers,
  }) {
    return PresenceState(
      onlineUsers: onlineUsers ?? this.onlineUsers,
      lastSeen: lastSeen ?? this.lastSeen,
      typingUsers: typingUsers ?? this.typingUsers,
      recordingUsers: recordingUsers ?? this.recordingUsers,
    );
  }

  bool isUserOnline(String userId) => onlineUsers[userId] ?? false;

  String getTypingUser(String chatId) => typingUsers[chatId] ?? '';
  String getRecordingUser(String chatId) => recordingUsers[chatId] ?? '';
}

final presenceProvider =
    NotifierProvider<PresenceNotifier, PresenceState>(PresenceNotifier.new);

class PresenceNotifier extends Notifier<PresenceState> {
  Timer? _heartbeatTimer;

  @override
  PresenceState build() => const PresenceState();

  /// Initialize all presence listeners and heartbeat
  void init() {
    final socket = ref.read(socketServiceProvider);

    // Heartbeat every 60s
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      socket.socket?.emit('heartbeat');
    });

    // Online
    socket.on('presence:online', (data) {
      if (data is Map<String, dynamic>) {
        final userId = data['userId']?.toString() ?? '';
        if (userId.isNotEmpty) {
          final updated = Map<String, bool>.from(state.onlineUsers);
          updated[userId] = true;
          state = state.copyWith(onlineUsers: updated);
        }
      }
    });

    // Offline
    socket.on('presence:offline', (data) {
      if (data is Map<String, dynamic>) {
        final userId = data['userId']?.toString() ?? '';
        if (userId.isNotEmpty) {
          final updated = Map<String, bool>.from(state.onlineUsers);
          updated[userId] = false;
          final ls = Map<String, DateTime>.from(state.lastSeen);
          ls[userId] = DateTime.now();
          state = state.copyWith(onlineUsers: updated, lastSeen: ls);
        }
      }
    });

    // Typing
    socket.on('typing:start', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString() ?? '';
        final userId = data['userId']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          final updated = Map<String, String>.from(state.typingUsers);
          updated[chatId] = userId;
          state = state.copyWith(typingUsers: updated);
        }
      }
    });

    socket.on('typing:stop', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          final updated = Map<String, String>.from(state.typingUsers);
          updated.remove(chatId);
          state = state.copyWith(typingUsers: updated);
        }
      }
    });

    // Recording
    socket.on('recording:start', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString() ?? '';
        final userId = data['userId']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          final updated = Map<String, String>.from(state.recordingUsers);
          updated[chatId] = userId;
          state = state.copyWith(recordingUsers: updated);
        }
      }
    });

    socket.on('recording:stop', (data) {
      if (data is Map<String, dynamic>) {
        final chatId = data['chatId']?.toString() ?? '';
        if (chatId.isNotEmpty) {
          final updated = Map<String, String>.from(state.recordingUsers);
          updated.remove(chatId);
          state = state.copyWith(recordingUsers: updated);
        }
      }
    });
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
