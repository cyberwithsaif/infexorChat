import 'dart:convert';
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
  static const _cacheBoxName = 'registered_contacts_cache';

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

  // ──────────────────────────────────────────────────────────
  //  CACHE HELPERS
  // ──────────────────────────────────────────────────────────

  /// Save registered contacts to Hive so they show instantly next time
  Future<void> _saveContactsToCache(List<Map<String, dynamic>> contacts) async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      // Store as a JSON-encoded list of maps
      final encoded = contacts.map((c) => jsonEncode(c)).toList();
      await box.put('contacts', encoded);
      debugPrint('💾 Saved ${contacts.length} contacts to cache');
    } catch (e) {
      debugPrint('⚠️ Failed to save contacts to cache: $e');
    }
  }

  /// Load registered contacts from Hive cache (instant)
  Future<List<Map<String, dynamic>>> _loadContactsFromCache() async {
    try {
      final box = await Hive.openBox(_cacheBoxName);
      final raw = box.get('contacts');
      if (raw is List) {
        final result = <Map<String, dynamic>>[];
        for (final item in raw) {
          try {
            final decoded = jsonDecode(item.toString());
            if (decoded is Map) {
              result.add(Map<String, dynamic>.from(decoded));
            }
          } catch (_) {}
        }
        debugPrint('💾 Loaded ${result.length} contacts from cache');
        return result;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load contacts from cache: $e');
    }
    return [];
  }

  // ──────────────────────────────────────────────────────────
  //  SMART SYNC: Show cached contacts instantly, sync in background
  // ──────────────────────────────────────────────────────────

  /// Called when ContactsScreen opens.
  /// 1. Instantly loads cached contacts (no spinner if cache exists).
  /// 2. Triggers a background sync to fetch updates.
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

    // ── Step 1: Load cached contacts instantly ──
    final cached = await _loadContactsFromCache();
    if (cached.isNotEmpty) {
      // Show cached contacts immediately — no loading spinner
      state = state.copyWith(
        status:
            ContactSyncStatus.syncing, // subtle indicator (e.g. refresh icon)
        registeredContacts: cached,
        error: null,
      );
    } else {
      // No cache — show a loading spinner (first time only)
      state = state.copyWith(
        status: ContactSyncStatus.syncing,
        registeredContacts: [],
        error: null,
      );
    }

    // ── Step 2: Background sync — read device contacts → hash → send to server ──
    try {
      final deviceContacts = await service.readDeviceContacts();

      if (deviceContacts.isEmpty) {
        state = state.copyWith(
          status: ContactSyncStatus.synced,
          // Keep cached contacts if device read returned nothing (e.g. permission hiccup)
          registeredContacts: cached.isNotEmpty ? cached : [],
        );
        return;
      }

      // --- Batch Processing Implementation ---
      final int chunkSize = 500;
      final List<Map<String, dynamic>> allMatched = [];

      final chunks = <List<Map<String, String>>>[];
      for (var i = 0; i < deviceContacts.length; i += chunkSize) {
        chunks.add(
          deviceContacts.sublist(
            i,
            i + chunkSize > deviceContacts.length
                ? deviceContacts.length
                : i + chunkSize,
          ),
        );
      }

      // Execute syncing in parallel
      final responses = await Future.wait(
        chunks.map((chunk) => service.syncWithServer(chunk)),
      );

      // Aggregate all matched contacts
      for (final response in responses) {
        final data = response['data'];
        final matchedInChunk = _safeListOfMaps(data?['contacts']);
        allMatched.addAll(matchedInChunk);
      }

      // Create map of normalized phone -> local name
      final deviceNameMap = <String, String>{};
      for (final c in deviceContacts) {
        if (c['phone'] != null && c['name'] != null) {
          deviceNameMap[c['phone']!] = c['name']!;
        }
      }

      // Enrich matched contacts with local names
      for (final m in allMatched) {
        final serverPhone =
            m['phone']?.toString() ?? m['user']?['phone']?.toString();

        if (serverPhone != null) {
          final normalized = serverPhone.replaceAll(
            RegExp(r'[\s\-\(\)\.\+]'),
            '',
          );

          if (deviceNameMap.containsKey(normalized)) {
            m['name'] = deviceNameMap[normalized];
          }
        }
      }

      // ── Step 3: Update state with fresh contacts ──
      state = state.copyWith(
        status: ContactSyncStatus.synced,
        registeredContacts: allMatched,
        allContacts: deviceContacts
            .map((c) => <String, dynamic>{...c})
            .toList(),
      );

      // ── Step 4: Persist to cache for next time ──
      await _saveContactsToCache(allMatched);
      _cacheContactNames(allMatched);
    } catch (e) {
      debugPrint('❌ Contact sync error: $e');
      // On error, keep cached contacts visible instead of showing empty
      state = state.copyWith(
        status: cached.isNotEmpty
            ? ContactSyncStatus.synced
            : ContactSyncStatus.error,
        registeredContacts: cached.isNotEmpty
            ? cached
            : state.registeredContacts,
        error: e.toString(),
      );
    }
  }

  /// Load contacts from server (without re-reading device)
  Future<void> loadFromServer() async {
    final service = ref.read(contactServiceProvider);

    // Load cache first
    final cached = await _loadContactsFromCache();
    if (cached.isNotEmpty) {
      state = state.copyWith(
        status: ContactSyncStatus.syncing,
        registeredContacts: cached,
        error: null,
      );
    } else {
      state = state.copyWith(status: ContactSyncStatus.syncing, error: null);
    }

    try {
      final response = await service.getContacts();
      final contacts = _safeListOfMaps(response['data']?['contacts']);

      state = state.copyWith(
        status: ContactSyncStatus.synced,
        registeredContacts: contacts,
      );
      await _saveContactsToCache(contacts);
      _cacheContactNames(contacts);
    } catch (e) {
      debugPrint('❌ loadFromServer error: $e');
      state = state.copyWith(
        status: cached.isNotEmpty
            ? ContactSyncStatus.synced
            : ContactSyncStatus.error,
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
