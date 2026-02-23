import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final contactServiceProvider = Provider<ContactService>((ref) {
  return ContactService(ref.read(apiClientProvider));
});

class ContactService {
  final ApiClient _api;

  ContactService(this._api);

  /// Request contacts permission
  Future<bool> requestPermission() async {
    final status = await Permission.contacts.request();
    return status.isGranted;
  }

  /// Check if contacts permission is granted
  Future<bool> hasPermission() async {
    return await Permission.contacts.isGranted;
  }

  /// Read device contacts and return hashed phone data
  Future<List<Map<String, String>>> readDeviceContacts() async {
    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    final List<Map<String, String>> result = [];

    // Debug logging
    print('Found ${contacts.length} device contacts');

    for (final contact in contacts) {
      for (final phone in contact.phones) {
        // Use normalizedNumber if available (usually E.164), otherwise raw number
        String numberToUse = phone.normalizedNumber.isNotEmpty
            ? phone.normalizedNumber
            : phone.number;

        final normalized = _normalizePhone(numberToUse);

        if (normalized.isNotEmpty) {
          result.add({
            'name': contact.displayName,
            'phone': normalized,
            'phoneHash': _hashPhone(normalized),
          });
        }
      }
    }

    print('Normalized ${result.length} phone numbers for sync');
    return result;
  }

  /// Sync contacts with server
  Future<Map<String, dynamic>> syncWithServer(
    List<Map<String, String>> contacts,
  ) async {
    print('Syncing ${contacts.length} contacts...');
    final response = await _api.post(
      ApiEndpoints.syncContacts,
      data: {'contacts': contacts},
    );
    return response.data;
  }

  /// Find a single user by phone number (Direct Chat)
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final hash = _hashPhone(normalized);

    final payload = [
      {'name': phone, 'phone': normalized, 'phoneHash': hash},
    ];

    print('Looking up user: $normalized (Hash: $hash)');

    try {
      final response = await syncWithServer(payload);

      // Handle response structure: { success: true, data: { contacts: [] } }
      final data = response['data'];
      if (data == null) return null;

      final matched = data['contacts'] as List?;

      if (matched != null && matched.isNotEmpty) {
        print('User found: ${matched.first}');
        return matched.first as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error finding user: $e');
    }

    return null;
  }

  /// Get synced contacts from server
  Future<Map<String, dynamic>> getContacts({bool all = false}) async {
    final response = await _api.get(
      ApiEndpoints.contacts,
      queryParams: all ? {'all': 'true'} : null,
    );
    return response.data;
  }

  /// Normalize phone number (strip spaces, dashes, parens, plus sign)
  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[\s\-\(\)\.\+]'), '');
  }

  /// SHA-256 hash a phone number
  String _hashPhone(String phone) {
    final bytes = utf8.encode(phone);
    return sha256.convert(bytes).toString();
  }
}
