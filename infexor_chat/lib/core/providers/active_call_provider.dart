import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global state for tracking an ongoing call that's been minimized
class ActiveCallState {
  final bool isActive;
  final String chatId;
  final String userId;
  final String callerName;
  final String? callerAvatar;
  final bool isVideoCall;
  final bool isIncoming;
  final int duration; // elapsed seconds

  const ActiveCallState({
    this.isActive = false,
    this.chatId = '',
    this.userId = '',
    this.callerName = '',
    this.callerAvatar,
    this.isVideoCall = false,
    this.isIncoming = false,
    this.duration = 0,
  });

  ActiveCallState copyWith({
    bool? isActive,
    String? chatId,
    String? userId,
    String? callerName,
    String? callerAvatar,
    bool? isVideoCall,
    bool? isIncoming,
    int? duration,
  }) {
    return ActiveCallState(
      isActive: isActive ?? this.isActive,
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      isVideoCall: isVideoCall ?? this.isVideoCall,
      isIncoming: isIncoming ?? this.isIncoming,
      duration: duration ?? this.duration,
    );
  }
}

class ActiveCallNotifier extends Notifier<ActiveCallState> {
  Timer? _durationTimer;

  @override
  ActiveCallState build() => const ActiveCallState();

  /// Called when user presses back on call screen (minimize)
  void setActiveCall({
    required String chatId,
    required String userId,
    required String callerName,
    String? callerAvatar,
    required bool isVideoCall,
    required bool isIncoming,
    required int currentDuration,
  }) {
    _durationTimer?.cancel();
    state = ActiveCallState(
      isActive: true,
      chatId: chatId,
      userId: userId,
      callerName: callerName,
      callerAvatar: callerAvatar,
      isVideoCall: isVideoCall,
      isIncoming: isIncoming,
      duration: currentDuration,
    );
    // Continue counting duration
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isActive) {
        state = state.copyWith(duration: state.duration + 1);
      }
    });
  }

  /// Called when user returns to call screen
  void clearActiveCall() {
    _durationTimer?.cancel();
    state = const ActiveCallState();
  }

  /// Called when call ends entirely
  void endCall() {
    _durationTimer?.cancel();
    state = const ActiveCallState();
  }

  String formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

final activeCallProvider =
    NotifierProvider<ActiveCallNotifier, ActiveCallState>(
      ActiveCallNotifier.new,
    );
