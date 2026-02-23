import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/contact_service.dart';

enum ContactSyncStatus { idle, syncing, synced, error, noPermission }

class ContactState {
  final ContactSyncStatus status;
  final List<Map<String, dynamic>> registeredContacts;
  final List<Map<String, dynamic>> allContacts;
  final String? error;

  const ContactState({
    this.status = ContactSyncStatus.idle,
    this.registeredContacts = const [],
    this.allContacts = const [],
    this.error,
  });

  ContactState copyWith({
    ContactSyncStatus? status,
    List<Map<String, dynamic>>? registeredContacts,
    List<Map<String, dynamic>>? allContacts,
    String? error,
  }) {
    return ContactState(
      status: status ?? this.status,
      registeredContacts: registeredContacts ?? this.registeredContacts,
      allContacts: allContacts ?? this.allContacts,
      error: error,
    );
  }
}

final contactProvider = NotifierProvider<ContactNotifier, ContactState>(
  ContactNotifier.new,
);

class ContactNotifier extends Notifier<ContactState> {
  @override
  ContactState build() => const ContactState();

  /// Safe list conversion helper
  List<Map<String, dynamic>> _safeListOfMaps(dynamic raw) {
    final result = <Map<String, dynamic>>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          result.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return result;
  }

  /// Load contacts from server first (instant display), then sync in background
  Future<void> syncContacts() async {
    final service = ref.read(contactServiceProvider);

    // Check permission
    final hasPermission = await service.hasPermission();
    if (!hasPermission) {
      final granted = await service.requestPermission();
      if (!granted) {
        state = state.copyWith(status: ContactSyncStatus.noPermission);
        return;
      }
    }

    // Clear stale contacts and show syncing state
    // (don't pre-load server cache — it may contain deleted/unsaved contacts)
    state = state.copyWith(
      status: ContactSyncStatus.syncing,
      registeredContacts: [],
      error: null,
    );

    // 2. Background sync: read device contacts → hash → send to server
    try {
      final deviceContacts = await service.readDeviceContacts();

      if (deviceContacts.isEmpty) {
        state = state.copyWith(
          status: ContactSyncStatus.synced,
          registeredContacts: [],
        );
        return;
      }

      final response = await service.syncWithServer(deviceContacts);
      final data = response['data'];
      final matched = _safeListOfMaps(data?['contacts']);

      // Create map of normalized phone -> local name
      final deviceNameMap = <String, String>{};
      for (final c in deviceContacts) {
        if (c['phone'] != null && c['name'] != null) {
          deviceNameMap[c['phone']!] = c['name']!;
        }
      }

      // Enrich matched contacts with local names
      for (final m in matched) {
        // Check phone in 'phone' or inside 'user' object
        final serverPhone =
            m['phone']?.toString() ?? m['user']?['phone']?.toString();

        if (serverPhone != null) {
          // Normalize server phone (remove + and non-digits) to match device format
          final normalized = serverPhone.replaceAll(
            RegExp(r'[\s\-\(\)\.\+]'),
            '',
          );

          if (deviceNameMap.containsKey(normalized)) {
            m['name'] = deviceNameMap[normalized];
          }
        }
      }

      state = state.copyWith(
        status: ContactSyncStatus.synced,
        registeredContacts: matched,
        allContacts: deviceContacts
            .map((c) => <String, dynamic>{...c})
            .toList(),
      );
      _cacheContactNames(matched);
    } catch (e) {
      debugPrint('❌ Contact sync error: $e');
      state = state.copyWith(
        status: ContactSyncStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Load contacts from server (without re-reading device)
  Future<void> loadFromServer() async {
    final service = ref.read(contactServiceProvider);
    state = state.copyWith(status: ContactSyncStatus.syncing, error: null);

    try {
      final response = await service.getContacts();
      final contacts = _safeListOfMaps(response['data']?['contacts']);

      state = state.copyWith(
        status: ContactSyncStatus.synced,
        registeredContacts: contacts,
      );
      _cacheContactNames(contacts);
    } catch (e) {
      debugPrint('❌ loadFromServer error: $e');
      state = state.copyWith(
        status: ContactSyncStatus.error,
        error: e.toString(),
      );
    }
  }

  /// Cache contact names for background service
  Future<void> _cacheContactNames(List<Map<String, dynamic>> contacts) async {
    try {
      final box = await Hive.openBox('contacts_cache');
      final nameMap = <String, String>{};
      for (final c in contacts) {
        // The contact object from server has '_id' (user ID) and 'name' (saved name from phone)
        // We map ID to Name so background service can look it up
        final id = c['user']?['_id']?.toString() ?? c['_id']?.toString();
        final name = c['name']?.toString() ?? c['user']?['name']?.toString();

        if (id != null && name != null) {
          nameMap[id] = name;
        }
      }
      if (nameMap.isNotEmpty) {
        await box.putAll(nameMap);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to cache contact names: $e');
    }
  }
}
