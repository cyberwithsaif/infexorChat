import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/animated_page_route.dart';
import '../services/group_service.dart';
import 'media_gallery_screen.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String chatId;

  const GroupInfoScreen({
    super.key,
    required this.groupId,
    required this.chatId,
  });

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  String _myRole = 'member';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    try {
      final service = ref.read(groupServiceProvider);
      final response = await service.getGroupInfo(widget.groupId);
      final data = response['data'] ?? response;

      setState(() {
        _group = data['group'] is Map
            ? Map<String, dynamic>.from(data['group'])
            : null;
        _members = List<Map<String, dynamic>>.from(data['members'] ?? []);
        _myRole = data['myRole']?.toString() ?? 'member';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load group info: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  bool get _isAdmin => _myRole == 'admin' || _myRole == 'superadmin';

  bool get _isSuperAdmin => _myRole == 'superadmin';

  Future<void> _removeMember(String memberId, String memberName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dlgTheme = Theme.of(ctx);
        final dlgIsDark = dlgTheme.brightness == Brightness.dark;
        final dlgTextColor = dlgTheme.textTheme.bodyLarge?.color ?? Colors.black;
        final dlgSubtitleColor = dlgTheme.textTheme.bodyMedium?.color ?? Colors.grey;
        final dlgCardColor = dlgIsDark ? AppColors.darkBgSecondary : AppColors.bgCard;
        return AlertDialog(
          backgroundColor: dlgCardColor,
          title: Text(
            'Remove Member',
            style: TextStyle(color: dlgTextColor),
          ),
          content: Text(
            'Remove $memberName from this group?',
            style: TextStyle(color: dlgSubtitleColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Remove',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ref
          .read(groupServiceProvider)
          .removeMember(widget.groupId, memberId);
      _loadGroupInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _changeRole(String memberId, String currentRole) async {
    final newRole = currentRole == 'admin' ? 'member' : 'admin';
    try {
      await ref
          .read(groupServiceProvider)
          .changeRole(widget.groupId, memberId, newRole);
      _loadGroupInfo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final dlgTheme = Theme.of(ctx);
        final dlgIsDark = dlgTheme.brightness == Brightness.dark;
        final dlgTextColor = dlgTheme.textTheme.bodyLarge?.color ?? Colors.black;
        final dlgSubtitleColor = dlgTheme.textTheme.bodyMedium?.color ?? Colors.grey;
        final dlgCardColor = dlgIsDark ? AppColors.darkBgSecondary : AppColors.bgCard;
        return AlertDialog(
          backgroundColor: dlgCardColor,
          title: Text(
            'Leave Group',
            style: TextStyle(color: dlgTextColor),
          ),
          content: Text(
            'Are you sure you want to leave this group?',
            style: TextStyle(color: dlgSubtitleColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Leave',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await ref.read(groupServiceProvider).leaveGroup(widget.groupId);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _shareInviteLink() async {
    try {
      final service = ref.read(groupServiceProvider);
      final response = await service.generateInviteLink(widget.groupId);
      final data = response['data'] ?? response;
      final link = data['inviteLink'] ?? '';

      if (link.isNotEmpty && mounted) {
        SharePlus.instance.share(
          ShareParams(
            text:
                'Join my group on Infexor Chat: https://infexor.chat/join/$link',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accentBlue),
        ),
      );
    }

    final groupName = _group?['name'] ?? 'Group';
    final groupDesc = _group?['description'] ?? '';
    final groupAvatar = _group?['avatar'] ?? '';
    final memberCount = _group?['memberCount'] ?? _members.length;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          // Collapsible header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: bgColor,
            iconTheme: IconThemeData(color: textColor),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                groupName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.primaryGradient,
                ),
                child: Center(
                  child: groupAvatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: groupAvatar,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                        )
                      : const Icon(
                          Icons.group_rounded,
                          size: 60,
                          color: Colors.white54,
                        ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // Description
                if (groupDesc.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      groupDesc,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 14,
                      ),
                    ),
                  ),

                // Actions row
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionButton(
                        icon: Icons.image_rounded,
                        label: 'Media',
                        onTap: () => Navigator.push(
                          context,
                          AnimatedPageRoute(
                            builder: (_) => MediaGalleryScreen(
                              chatId: widget.chatId,
                              chatName: _group?['name'] ?? 'Group',
                            ),
                          ),
                        ),
                      ),
                      if (_isAdmin)
                        _ActionButton(
                          icon: Icons.link_rounded,
                          label: 'Invite',
                          onTap: _shareInviteLink,
                        ),
                      _ActionButton(
                        icon: Icons.notifications_off_rounded,
                        label: 'Mute',
                        onTap: () async {
                          await ref
                              .read(groupServiceProvider)
                              .muteGroup(
                                widget.groupId,
                                until: DateTime.now().add(
                                  const Duration(hours: 8),
                                ),
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Muted for 8 hours'),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Members header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        color: subtitleColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$memberCount members',
                        style: TextStyle(
                          color: subtitleColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Members list
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final member = _members[index];
              final user = member['userId'];
              final name = user?['name'] ?? 'Unknown';
              final avatar = user?['avatar'] ?? '';
              final role = member['role'] ?? 'member';
              final memberId = user?['_id'] ?? '';
              final isOnline = user?['isOnline'] == true;

              return ListTile(
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.bgHover,
                      backgroundImage: avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                color: subtitleColor,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.online,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: bgColor,
                              width: 2,
                            ),
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
                subtitle: role != 'member'
                    ? Text(
                        role == 'superadmin' ? 'Group admin' : 'Admin',
                        style: TextStyle(
                          color: role == 'superadmin'
                              ? AppColors.accentBlue
                              : AppColors.accentPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    : null,
                trailing: _isAdmin && role != 'superadmin'
                    ? PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: subtitleColor,
                          size: 20,
                        ),
                        color: cardColor,
                        onSelected: (action) {
                          switch (action) {
                            case 'make_admin':
                            case 'remove_admin':
                              _changeRole(memberId, role);
                              break;
                            case 'remove':
                              _removeMember(memberId, name);
                              break;
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (_isSuperAdmin)
                            PopupMenuItem(
                              value: role == 'admin'
                                  ? 'remove_admin'
                                  : 'make_admin',
                              child: Text(
                                role == 'admin' ? 'Remove admin' : 'Make admin',
                                style: TextStyle(
                                  color: textColor,
                                ),
                              ),
                            ),
                          PopupMenuItem(
                            value: 'remove',
                            child: Text(
                              'Remove $name',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      )
                    : null,
              );
            }, childCount: _members.length),
          ),

          // Leave group button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: OutlinedButton.icon(
                onPressed: _leaveGroup,
                icon: const Icon(Icons.exit_to_app, color: AppColors.danger),
                label: const Text(
                  'Exit Group',
                  style: TextStyle(color: AppColors.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.accentBlue, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
