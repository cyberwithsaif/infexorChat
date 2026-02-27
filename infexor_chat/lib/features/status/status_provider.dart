import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/chat/services/socket_service.dart';
import 'status_service.dart';

class StatusState {
  final List<Map<String, dynamic>> myStatuses;
  final List<Map<String, dynamic>> contactStatuses; // grouped by user
  final bool isLoading;
  final String? error;

  const StatusState({
    this.myStatuses = const [],
    this.contactStatuses = const [],
    this.isLoading = false,
    this.error,
  });

  StatusState copyWith({
    List<Map<String, dynamic>>? myStatuses,
    List<Map<String, dynamic>>? contactStatuses,
    bool? isLoading,
    String? error,
  }) {
    return StatusState(
      myStatuses: myStatuses ?? this.myStatuses,
      contactStatuses: contactStatuses ?? this.contactStatuses,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final statusProvider = NotifierProvider<StatusNotifier, StatusState>(
  StatusNotifier.new,
);

class StatusNotifier extends Notifier<StatusState> {
  @override
  StatusState build() => const StatusState();

  /// Load all statuses (my + contacts')
  Future<void> loadStatuses() async {
    state = state.copyWith(isLoading: true);
    try {
      final service = ref.read(statusServiceProvider);
      final myRes = await service.getMyStatuses();
      final contactRes = await service.getContactStatuses();

      final myStatuses = <Map<String, dynamic>>[];
      final rawMy = myRes['data']?['statuses'] ?? [];
      if (rawMy is List) {
        for (final s in rawMy) {
          if (s is Map) myStatuses.add(Map<String, dynamic>.from(s));
        }
      }

      final contactStatuses = <Map<String, dynamic>>[];
      final rawContacts = contactRes['data']?['contactStatuses'] ?? [];
      if (rawContacts is List) {
        for (final g in rawContacts) {
          if (g is Map) contactStatuses.add(Map<String, dynamic>.from(g));
        }
      }

      state = state.copyWith(
        myStatuses: myStatuses,
        contactStatuses: contactStatuses,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Create a text status
  Future<bool> createTextStatus(String content, String backgroundColor) async {
    try {
      await ref
          .read(statusServiceProvider)
          .createTextStatus(content: content, backgroundColor: backgroundColor);
      await loadStatuses(); // refresh
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Create a media status
  Future<bool> createMediaStatus(
    Map<String, dynamic> media,
    String caption,
    String type,
  ) async {
    try {
      await ref
          .read(statusServiceProvider)
          .createMediaStatus(media: media, caption: caption, type: type);
      await loadStatuses();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Mark status as viewed
  Future<void> viewStatus(String statusId) async {
    try {
      final currentUserId =
          ref.read(authProvider).user?['_id']?.toString() ?? '';

      final updatedContacts = state.contactStatuses.map((group) {
        final newStatuses = List<Map<String, dynamic>>.from(
          group['statuses'] ?? [],
        );
        bool changesMade = false;

        for (int i = 0; i < newStatuses.length; i++) {
          if (newStatuses[i]['_id'] == statusId) {
            final viewers = List<dynamic>.from(newStatuses[i]['viewers'] ?? []);
            if (!viewers.any((v) {
              final u = v['userId'];
              if (u is Map) return u['_id']?.toString() == currentUserId;
              return u?.toString() == currentUserId;
            })) {
              viewers.add({
                'userId': currentUserId,
                'viewedAt': DateTime.now().toIso8601String(),
              });
              newStatuses[i] = {...newStatuses[i], 'viewers': viewers};
              changesMade = true;
            }
          }
        }

        if (!changesMade) return group;

        bool stillHasUnviewed = false;
        for (final s in newStatuses) {
          final vws = List<dynamic>.from(s['viewers'] ?? []);
          if (!vws.any((v) {
            final u = v['userId'];
            if (u is Map) return u['_id']?.toString() == currentUserId;
            return u?.toString() == currentUserId;
          })) {
            stillHasUnviewed = true;
            break;
          }
        }

        return {
          ...group,
          'statuses': newStatuses,
          'hasUnviewed': stillHasUnviewed,
        };
      }).toList();

      state = state.copyWith(contactStatuses: updatedContacts);

      await ref.read(statusServiceProvider).viewStatus(statusId);
    } catch (_) {}
  }

  /// Delete own status
  Future<void> deleteStatus(String statusId) async {
    try {
      await ref.read(statusServiceProvider).deleteStatus(statusId);
      state = state.copyWith(
        myStatuses: state.myStatuses
            .where((s) => s['_id'] != statusId)
            .toList(),
      );
    } catch (_) {}
  }

  static bool _listenersInitialized = false;

  /// Initialize socket listeners for real-time status updates
  void initSocketListeners() {
    if (_listenersInitialized) return;
    _listenersInitialized = true;

    final socket = ref.read(socketServiceProvider);
    final currentUserId = ref.read(authProvider).user?['_id'] ?? '';

    socket.on('status:new', (data) {
      if (data is Map<String, dynamic>) {
        final status = data['status'];
        if (status is Map) {
          final statusMap = Map<String, dynamic>.from(status);
          final userId = statusMap['userId'];
          final statusUserId = userId is Map
              ? userId['_id']?.toString()
              : userId?.toString();

          if (statusUserId == currentUserId) {
            // My own status
            state = state.copyWith(
              myStatuses: [statusMap, ...state.myStatuses],
            );
          } else {
            // Contact's status — refresh to get proper grouping
            loadStatuses();
          }
        }
      }
    });

    socket.on('status:deleted', (data) {
      if (data is Map<String, dynamic>) {
        final statusId = data['statusId']?.toString();
        final userId = data['userId']?.toString();

        if (userId == currentUserId) {
          state = state.copyWith(
            myStatuses: state.myStatuses
                .where((s) => s['_id'] != statusId)
                .toList(),
          );
        } else {
          // Refresh contacts
          loadStatuses();
        }
      }
    });
  }
}
