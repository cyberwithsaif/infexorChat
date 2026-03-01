import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../services/user_service.dart';
import '../services/media_service.dart';
import 'media_gallery_screen.dart';
import 'starred_messages_screen.dart';
import 'call_screen.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final String chatId;
  final String? contactName;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.chatId,
    this.contactName,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  int _mediaCount = 0;
  bool _isBlocked = false;
  bool _isLoadingBlock = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _loadMediaCount();
    _checkBlockStatus();
  }

  Future<void> _loadMediaCount() async {
    try {
      final result = await ref
          .read(mediaServiceProvider)
          .getChatMedia(widget.chatId, type: 'all', page: 1, limit: 1);
      // API may return totalCount or total or media list length
      final count = result['totalCount'] ?? result['total'] ?? 0;
      if (mounted) setState(() => _mediaCount = count is int ? count : 0);
    } catch (_) {
      // Silently fail — keep at 0
    }
  }

  Future<void> _saveContact() async {
    try {
      final granted = await FlutterContacts.requestPermission();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
        return;
      }

      final rawPhone = widget.user['phone'] ?? '';
      final name = widget.contactName ?? widget.user['name'] ?? 'Unknown';

      final newContact = Contact()
        ..name = Name(first: name)
        ..phones = [Phone(rawPhone)];

      await FlutterContacts.insertContact(newContact);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$name" saved to contacts'),
            backgroundColor: AppColors.accentBlue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save contact: $e')));
      }
    }
  }

  Future<void> _checkBlockStatus() async {
    try {
      final userId = widget.user['_id'];
      if (userId == null) {
        if (mounted) setState(() => _isLoadingBlock = false);
        return;
      }
      final result = await ref
          .read(userServiceProvider)
          .checkBlockStatus(userId);
      if (mounted) {
        setState(() {
          _isBlocked = result['blockedByMe'] == true;
          _isLoadingBlock = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBlock = false);
    }
  }

  Future<void> _toggleBlock() async {
    final userId = widget.user['_id'];
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error: User ID not found')));
      return;
    }

    final action = _isBlocked ? 'Unblock' : 'Block';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action ${widget.user['name']}?'),
        content: Text(
          _isBlocked
              ? 'This contact will be able to call you and send you messages again.'
              : 'Blocked contacts will no longer be able to call you or send you messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (_isBlocked) {
        await ref.read(userServiceProvider).unblockUser(userId);
      } else {
        await ref.read(userServiceProvider).blockUser(userId);
      }

      if (mounted) {
        setState(() => _isBlocked = !_isBlocked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isBlocked
                  ? '${widget.user['name']} has been blocked'
                  : '${widget.user['name']} has been unblocked',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to $action user')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final registeredName = widget.user['name'] ?? 'Unknown';
    final name = widget.contactName ?? registeredName;
    final rawPhone = widget.user['phone'] ?? '';
    final phone = PhoneUtils.formatPhoneDisplay(rawPhone).isNotEmpty
        ? PhoneUtils.formatPhoneDisplay(rawPhone)
        : rawPhone;
    final about = widget.user['about'] ?? 'Hey there! I am using Infexor Chat.';
    // Enforce profile photo privacy setting
    final privacySettings =
        widget.user['privacySettings'] as Map<String, dynamic>? ?? {};
    final photoVisibility =
        privacySettings['profilePhoto']?.toString() ?? 'everyone';
    final rawAvatar = widget.user['avatar'] ?? '';
    final avatar = photoVisibility == 'nobody'
        ? ''
        : UrlUtils.getFullUrl(rawAvatar);
    final isOnline = widget.user['isOnline'] == true;

    final isDark2 = Theme.of(context).brightness == Brightness.dark;
    final bgColor2 = Theme.of(context).scaffoldBackgroundColor;
    final appBarBg = isDark2
        ? AppColors.darkBgSecondary
        : AppColors.bgSecondary;

    return Scaffold(
      backgroundColor: bgColor2,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: appBarBg,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  avatar.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: avatar,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: AppColors.accentBlue),
                          errorWidget: (context, url, error) => Container(
                            color: AppColors.accentBlue,
                            child: const Icon(
                              Icons.person,
                              size: 100,
                              color: Colors.white54,
                            ),
                          ),
                        )
                      : Container(
                          color: AppColors.accentBlue,
                          child: const Icon(
                            Icons.person,
                            size: 100,
                            color: Colors.white54,
                          ),
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                        stops: [0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                // Info Card
                Container(
                  color: appBarBg,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'About and phone number',
                        style: TextStyle(
                          color: AppColors.accentBlue,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        about,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark2 ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '~ $registeredName',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const Divider(height: 24),
                      Text(
                        phone,
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark2 ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Mobile',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _ActionButton(
                            icon: Icons.call,
                            label: 'Voice',
                            onTap: () {
                              final userId = widget.user['_id'];
                              if (userId == null) return;
                              Navigator.push(
                                context,
                                AnimatedPageRoute(
                                  builder: (_) => CallPage(
                                    chatId: widget.chatId,
                                    userId: userId,
                                    callerName:
                                        widget.user['name'] ?? 'Unknown',
                                    callerAvatar: widget.user['avatar'],
                                    isVideoCall: false,
                                    isIncoming: false,
                                  ),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: Icons.videocam,
                            label: 'Video',
                            onTap: () {
                              final userId = widget.user['_id'];
                              if (userId == null) return;
                              Navigator.push(
                                context,
                                AnimatedPageRoute(
                                  builder: (_) => CallPage(
                                    chatId: widget.chatId,
                                    userId: userId,
                                    callerName:
                                        widget.user['name'] ?? 'Unknown',
                                    callerAvatar: widget.user['avatar'],
                                    isVideoCall: true,
                                    isIncoming: false,
                                  ),
                                ),
                              );
                            },
                          ),
                          _ActionButton(
                            icon: Icons.search,
                            label: 'Search',
                            onTap: () {
                              // Pop back to conversation and open search
                              Navigator.pop(context, 'open_search');
                            },
                          ),
                          _ActionButton(
                            icon: Icons.person_add,
                            label: 'Save',
                            onTap: _saveContact,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Media & Common
                Container(
                  color: appBarBg,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.image,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'Media, links, and docs',
                          style: TextStyle(
                            color: isDark2 ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_mediaCount',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.textMuted,
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            AnimatedPageRoute(
                              builder: (_) => MediaGalleryScreen(
                                chatId: widget.chatId,
                                chatName: name,
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 72,
                        color: isDark2 ? Colors.white10 : AppColors.border,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.star_border,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'Starred messages',
                          style: TextStyle(
                            color: isDark2 ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDark2 ? Colors.white54 : AppColors.textMuted,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            AnimatedPageRoute(
                              builder: (_) => StarredMessagesScreen(
                                chatId: widget.chatId,
                                chatName:
                                    widget.contactName ??
                                    widget.user['name'] ??
                                    'Contact',
                              ),
                            ),
                          );
                        },
                      ),
                      Divider(
                        height: 1,
                        indent: 72,
                        color: isDark2 ? Colors.white10 : AppColors.border,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_none,
                          color: AppColors.textSecondary,
                        ),
                        title: Text(
                          'Mute notifications',
                          style: TextStyle(
                            color: isDark2 ? Colors.white : Colors.black,
                          ),
                        ),
                        trailing: Switch(
                          value: _isMuted,
                          onChanged: (v) {
                            setState(() => _isMuted = v);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  v
                                      ? 'Notifications muted'
                                      : 'Notifications unmuted',
                                ),
                              ),
                            );
                          },
                          inactiveTrackColor: isDark2
                              ? Colors.white10
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),

                // Actions
                Container(
                  color: appBarBg,
                  margin: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.block,
                          color: AppColors.danger,
                        ),
                        title: _isLoadingBlock
                            ? const Text(
                                'Loading...',
                                style: TextStyle(color: AppColors.textMuted),
                              )
                            : Text(
                                _isBlocked ? 'Unblock' : 'Block',
                                style: const TextStyle(color: AppColors.danger),
                              ),
                        onTap: _isLoadingBlock ? null : _toggleBlock,
                      ),
                      Divider(
                        height: 1,
                        indent: 72,
                        color: isDark2 ? Colors.white10 : AppColors.border,
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.thumb_down_outlined,
                          color: AppColors.danger,
                        ),
                        title: const Text(
                          'Report contact',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
      child: Column(
        children: [
          Icon(icon, color: AppColors.accentBlue, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.accentBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
