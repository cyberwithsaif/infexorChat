import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../contacts/providers/contact_provider.dart';
import '../services/group_service.dart';
import 'conversation_screen.dart';

class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _searchController = TextEditingController();
  final Set<String> _selectedIds = {};
  bool _isCreating = false;
  int _step = 0; // 0 = select members, 1 = set group info

  @override
  void initState() {
    super.initState();
    // Sync contacts so only current device contacts appear (not stale/deleted ones)
    Future.microtask(() {
      ref.read(contactProvider.notifier).syncContacts();
    });
  }

  /// Extract userId from contact (handles both flat and nested formats)
  String _getUserId(Map<String, dynamic> contact) {
    final contactUser = contact['contactUserId'];
    if (contactUser is Map) {
      return (contactUser['_id'] ?? contactUser['id'] ?? '').toString();
    }
    if (contactUser != null) return contactUser.toString();
    return (contact['_id'] ?? contact['id'] ?? '').toString();
  }

  /// Extract display name from contact (handles both flat and nested formats)
  String _getName(Map<String, dynamic> contact) {
    // Flat format: name is directly on the contact
    final localName = contact['name']?.toString();
    if (localName != null && localName.isNotEmpty) return localName;

    // Nested format: name inside contactUserId object
    final contactUser = contact['contactUserId'];
    if (contactUser is Map) {
      return (contactUser['name'] ?? 'Unknown').toString();
    }

    return contact['serverName']?.toString() ??
        contact['phone']?.toString() ??
        'Unknown';
  }

  /// Extract avatar from contact (handles both flat and nested formats)
  String _getAvatar(Map<String, dynamic> contact) {
    final directAvatar = contact['avatar']?.toString();
    if (directAvatar != null && directAvatar.isNotEmpty) return directAvatar;

    final contactUser = contact['contactUserId'];
    if (contactUser is Map) {
      return (contactUser['avatar'] ?? '').toString();
    }
    return '';
  }

  /// Extract about from contact (handles both flat and nested formats)
  String _getAbout(Map<String, dynamic> contact) {
    final directAbout = contact['about']?.toString();
    if (directAbout != null && directAbout.isNotEmpty) return directAbout;

    final contactUser = contact['contactUserId'];
    if (contactUser is Map) {
      return (contactUser['about'] ?? '').toString();
    }
    return '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredContacts {
    final contacts = ref.read(contactProvider).registeredContacts;
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return contacts;
    return contacts
        .where(
          (c) =>
              (c['name'] ?? '').toString().toLowerCase().contains(query) ||
              (c['phone'] ?? '').toString().contains(query),
        )
        .toList();
  }

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;
    if (_selectedIds.isEmpty) return;

    setState(() => _isCreating = true);

    try {
      final groupService = ref.read(groupServiceProvider);
      final response = await groupService.createGroup(
        name: _nameController.text.trim(),
        memberIds: _selectedIds.toList(),
        description: _descController.text.trim(),
      );

      if (!mounted) return;

      final data = response['data'] ?? response;
      final chatId = data['chatId']?.toString() ?? '';
      final groupData = data['group'];
      final groupId = groupData?['_id']?.toString() ?? '';
      final groupName = groupData?['name'] ?? _nameController.text.trim();

      Navigator.of(context).pushReplacement(
        AnimatedPageRoute(
          builder: (_) => ConversationScreen(
            chatId: chatId,
            chatName: groupName,
            isGroup: true,
            groupId: groupId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create group: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    final contactState = ref.watch(contactProvider);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          _step == 0 ? 'Add Members' : 'New Group',
          style: TextStyle(color: textColor),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_step == 0 && _selectedIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _step = 1),
              child: const Text('Next'),
            ),
        ],
      ),
      body: _step == 0
          ? _buildMemberSelection(
              contactState,
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
              bgColor: bgColor,
              isDark: isDark,
            )
          : _buildGroupInfo(
              textColor: textColor,
              subtitleColor: subtitleColor,
              cardColor: cardColor,
            ),
      floatingActionButton: _step == 1
          ? FloatingActionButton(
              onPressed: _isCreating ? null : _createGroup,
              backgroundColor: AppColors.accentBlue,
              child: _isCreating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildMemberSelection(
    ContactState contactState, {
    required Color textColor,
    required Color subtitleColor,
    required Color cardColor,
    required Color bgColor,
    required bool isDark,
  }) {
    return Column(
      children: [
        // Selected chips
        if (_selectedIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBgSecondary : AppColors.border,
                ),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _selectedIds.map((id) {
                final contact = contactState.registeredContacts.firstWhere(
                  (c) => _getUserId(c) == id,
                  orElse: () => <String, dynamic>{'name': 'Unknown'},
                );

                return Chip(
                  label: Text(
                    _getName(contact),
                    style: TextStyle(color: textColor, fontSize: 13),
                  ),
                  backgroundColor: cardColor,
                  deleteIconColor: subtitleColor,
                  side: BorderSide.none,
                  onDeleted: () => setState(() => _selectedIds.remove(id)),
                );
              }).toList(),
            ),
          ),

        // Search
        Container(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: TextStyle(color: subtitleColor),
              prefixIcon: Icon(Icons.search, color: subtitleColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Contact list
        Expanded(
          child: contactState.status == ContactSyncStatus.syncing
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue),
                )
              : ListView.builder(
                  itemCount: _filteredContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _filteredContacts[index];
                    final userId = _getUserId(contact);
                    final name = _getName(contact);
                    final avatar = _getAvatar(contact);
                    final about = _getAbout(contact);
                    final isSelected = _selectedIds.contains(userId);

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.bgHover,
                            backgroundImage: avatar.isNotEmpty
                                ? CachedNetworkImageProvider(avatar)
                                : null,
                            child: avatar.isEmpty
                                ? Text(
                                    name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(color: subtitleColor),
                                  )
                                : null,
                          ),
                          if (isSelected)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentBlue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        about,
                        style: TextStyle(color: subtitleColor, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedIds.remove(userId);
                          } else {
                            _selectedIds.add(userId);
                          }
                        });
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroupInfo({
    required Color textColor,
    required Color subtitleColor,
    required Color cardColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Group avatar placeholder
          GestureDetector(
            onTap: () {
              // TODO: pick group avatar
            },
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentBlue.withValues(alpha: 0.3),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Group name
          TextField(
            controller: _nameController,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: TextStyle(color: subtitleColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.group, color: subtitleColor),
            ),
          ),
          const SizedBox(height: 12),

          // Description
          TextField(
            controller: _descController,
            style: TextStyle(color: textColor, fontSize: 16),
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Group description (optional)',
              hintStyle: TextStyle(color: subtitleColor),
              filled: true,
              fillColor: cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.info_outline, color: subtitleColor),
            ),
          ),
          const SizedBox(height: 24),

          // Members preview
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Members: ${_selectedIds.length}',
              style: TextStyle(
                color: subtitleColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _selectedIds.map((id) {
                final contacts = ref.read(contactProvider).registeredContacts;
                final contact = contacts.firstWhere(
                  (c) => _getUserId(c) == id,
                  orElse: () => <String, dynamic>{'name': 'Unknown'},
                );

                return Chip(
                  label: Text(
                    _getName(contact),
                    style: TextStyle(color: textColor, fontSize: 12),
                  ),
                  backgroundColor: AppColors.bgHover,
                  side: BorderSide.none,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
