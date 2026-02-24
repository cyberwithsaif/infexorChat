import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/call_log.dart';
import '../repositories/call_repository.dart';

final callHistoryProvider =
    NotifierProvider<CallHistoryNotifier, AsyncValue<List<CallLog>>>(() {
      return CallHistoryNotifier();
    });

class CallHistoryNotifier extends Notifier<AsyncValue<List<CallLog>>> {
  @override
  AsyncValue<List<CallLog>> build() {
    // Start fetching immediately, but return loading as initial state
    Future.microtask(() => fetchCallHistory());
    return const AsyncValue.loading();
  }

  Future<void> fetchCallHistory() async {
    try {
      state = const AsyncValue.loading();
      final callRepository = ref.read(callRepositoryProvider);
      final calls = await callRepository.getCallHistory();
      state = AsyncValue.data(calls);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> logCall({
    String? callerId,
    required String receiverId,
    required String type, // 'audio' or 'video'
    required String status, // 'missed', 'completed', 'declined'
    int duration = 0,
  }) async {
    final callRepository = ref.read(callRepositoryProvider);
    final success = await callRepository.recordCall(
      callerId: callerId,
      receiverId: receiverId,
      type: type,
      status: status,
      duration: duration,
    );

    if (success) {
      // Refresh the list after successfully logging a new call
      fetchCallHistory();
    }
  }
}
