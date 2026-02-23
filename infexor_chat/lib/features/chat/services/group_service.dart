import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';

final groupServiceProvider = Provider<GroupService>((ref) {
  return GroupService(ref.read(apiClientProvider));
});

class GroupService {
  final ApiClient _api;

  GroupService(this._api);

  /// Create a new group
  Future<Map<String, dynamic>> createGroup({
    required String name,
    required List<String> memberIds,
    String? description,
    String? avatar,
  }) async {
    final response = await _api.post(
      ApiEndpoints.createGroup,
      data: {
        'name': name,
        'memberIds': memberIds,
        'description': ?description,
        'avatar': ?avatar,
      },
    );
    return response.data;
  }

  /// Get group info with members
  Future<Map<String, dynamic>> getGroupInfo(String groupId) async {
    final response = await _api.get('${ApiEndpoints.groups}/$groupId');
    return response.data;
  }

  /// Update group info
  Future<Map<String, dynamic>> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? avatar,
  }) async {
    final response = await _api.put(
      '${ApiEndpoints.groups}/$groupId',
      data: {'name': ?name, 'description': ?description, 'avatar': ?avatar},
    );
    return response.data;
  }

  /// Add members to group
  Future<void> addMembers(String groupId, List<String> memberIds) async {
    await _api.post(
      '${ApiEndpoints.groups}/$groupId/members',
      data: {'memberIds': memberIds},
    );
  }

  /// Remove a member from group
  Future<void> removeMember(String groupId, String memberId) async {
    await _api.delete('${ApiEndpoints.groups}/$groupId/members/$memberId');
  }

  /// Change member role
  Future<void> changeRole(String groupId, String memberId, String role) async {
    await _api.put(
      '${ApiEndpoints.groups}/$groupId/members/$memberId/role',
      data: {'role': role},
    );
  }

  /// Generate/regenerate invite link
  Future<Map<String, dynamic>> generateInviteLink(String groupId) async {
    final response = await _api.post(
      '${ApiEndpoints.groups}/$groupId/invite-link',
    );
    return response.data;
  }

  /// Toggle invite link on/off
  Future<void> toggleInviteLink(String groupId, bool enabled) async {
    await _api.put(
      '${ApiEndpoints.groups}/$groupId/invite-link',
      data: {'enabled': enabled},
    );
  }

  /// Join group via invite link
  Future<Map<String, dynamic>> joinViaLink(String inviteLink) async {
    final response = await _api.post('${ApiEndpoints.groups}/join/$inviteLink');
    return response.data;
  }

  /// Leave group
  Future<void> leaveGroup(String groupId) async {
    await _api.post('${ApiEndpoints.groups}/$groupId/leave');
  }

  /// Mute/unmute group
  Future<void> muteGroup(String groupId, {DateTime? until}) async {
    await _api.put(
      '${ApiEndpoints.groups}/$groupId/mute',
      data: {'until': until?.toIso8601String()},
    );
  }

  /// Update group settings
  Future<void> updateSettings(
    String groupId, {
    bool? onlyAdminsCanSend,
    bool? onlyAdminsCanEditInfo,
    bool? approvalRequired,
  }) async {
    await _api.put(
      '${ApiEndpoints.groups}/$groupId/settings',
      data: {
        'onlyAdminsCanSend': ?onlyAdminsCanSend,
        'onlyAdminsCanEditInfo': ?onlyAdminsCanEditInfo,
        'approvalRequired': ?approvalRequired,
      },
    );
  }
}
