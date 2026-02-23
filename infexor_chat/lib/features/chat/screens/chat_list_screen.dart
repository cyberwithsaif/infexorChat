import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/animations/page_transitions.dart';
import '../../../core/utils/animation_helpers.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'create_group_screen.dart';
import 'conversation_screen.dart';
import '../../settings/screens/settings_screen.dart';

import '../../../core/utils/phone_utils.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  Box? _contactsBox;

  @override
  void initState() {
    super.initState();
    _openContactsCache();
    Future.microtask(() {
      // Load chats
      ref.read(chatListProvider.notifier).loadChats();
      ref.read(chatListProvider.notifier).initSocketListeners();
    });
  }

  Future<void> _openContactsCache() async {
    try {
      _contactsBox = await Hive.openBox('contacts_cache');
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatListProvider);

    final currentUser = ref.watch(authProvider).user;
    final currentUserId = currentUser?['_id'] ?? '';

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final iconColor = isDark
        ? AppColors.darkTextSecondary
        : const Color(0xFF54656F);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          AppStrings.appName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        iconTheme: IconThemeData(color: iconColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: ChatSearchDelegate(
                  chats: chatState.chats,
                  currentUserId: currentUserId,
                  contactsBox: _contactsBox,
                ),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: bgColor,
            onSelected: (value) {
              if (value == 'new_group') {
                Navigator.push(
                  context,
                  InfexorPageRoute(page: const CreateGroupScreen()),
                );
              } else if (value == 'settings') {
                Navigator.push(
                  context,
                  InfexorPageRoute(page: const SettingsScreen()),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'new_group',
                child: Text('New Group', style: TextStyle(color: textColor)),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Text('Settings', style: TextStyle(color: textColor)),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        color: bgColor,
        child:
            (chatState.isLoading && chatState.chats.isEmpty) ||
                currentUserId.isEmpty
            ? const SizedBox.shrink()
            : chatState.error != null && chatState.chats.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load chats',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(chatListProvider.notifier).loadChats(),
                      child: const Text('Tap to retry'),
                    ),
                  ],
                ),
              )
            : chatState.chats.isEmpty
            ? const _EmptyChats()
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(chatListProvider.notifier).loadChats(),
                color: AppColors.accentBlue,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  cacheExtent: 1000,
                  itemCount: chatState.chats.length,
                  itemBuilder: (context, index) {
                    return RepaintBoundary(
                      child: _ChatTile(
                        chat: chatState.chats[index],
                        currentUserId: currentUserId,
                        contactsBox: _contactsBox,
                        onReturn: () =>
                            ref.read(chatListProvider.notifier).loadChats(),
                      ),
                    );
                  },
                ),
              ),
      ),

      floatingActionButton: AnimatedFabEntrance(
        child: FloatingActionButton(
          onPressed: () => context.push('/contacts'),
          backgroundColor: AppColors.fabBg, // Blue FAB
          foregroundColor: Colors.white,
          child: const Icon(Icons.message_rounded),
        ),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: subtitleColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Welcome to Infexor Chat',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to start a conversation',
            style: TextStyle(fontSize: 14, color: subtitleColor),
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final String currentUserId;
  final Box? contactsBox;
  final VoidCallback? onReturn;

  const _ChatTile({
    required this.chat,
    required this.currentUserId,
    this.contactsBox,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    try {
      return _buildTile(context);
    } catch (e) {
      final textColor =
          Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
      final subtitleColor =
          Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
      return ListTile(
        leading: const CircleAvatar(child: Icon(Icons.error_outline)),
        title: Text('Chat', style: TextStyle(color: textColor)),
        subtitle: Text(
          'Error: $e',
          style: TextStyle(fontSize: 12, color: subtitleColor),
        ),
      );
    }
  }

  Widget _buildTile(BuildContext buildContext) {
    final context = buildContext;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;
    // Determine if group chat
    final isGroup = chat['type'] == 'group';
    final groupData = chat['groupId'];

    // Get display name/avatar
    String name;
    String avatar;
    bool isOnline;
    final String groupId;

    if (isGroup && groupData is Map) {
      name = groupData['name']?.toString() ?? 'Group';
      avatar = groupData['avatar']?.toString() ?? '';
      isOnline = false;
      groupId = groupData['_id']?.toString() ?? '';
    } else {
      // 1:1 chat — get the other participant safely
      try {
        final rawParticipants = chat['participants'] ?? [];
        final participants = <Map<String, dynamic>>[];
        if (rawParticipants is List) {
          for (final p in rawParticipants) {
            if (p is Map) {
              participants.add(Map<String, dynamic>.from(p));
            }
          }
        }
        final other = participants.firstWhere(
          (p) => p['_id'] != currentUserId,
          orElse: () => <String, dynamic>{
            'name': 'Unknown',
            'avatar': '',
            'isOnline': false,
          },
        );
        // Look up saved contact name from device contacts cache
        final otherId = other['_id']?.toString();
        String? savedName;
        if (otherId != null && contactsBox != null && contactsBox!.isOpen) {
          savedName = contactsBox!.get(otherId)?.toString();
        }
        // Show saved contact name if available, otherwise formatted phone (like WhatsApp)
        final phone = other['phone']?.toString();
        final registeredName = other['name']?.toString();
        final formattedPhone = PhoneUtils.formatPhoneDisplay(phone);
        name =
            savedName ??
            (formattedPhone.isNotEmpty
                ? formattedPhone
                : registeredName ?? 'Unknown');

        // Enforce profile photo privacy
        final privacySettings =
            other['privacySettings'] as Map<String, dynamic>? ?? {};
        final photoVisibility =
            privacySettings['profilePhoto']?.toString() ?? 'everyone';
        avatar = photoVisibility == 'nobody'
            ? ''
            : (other['avatar']?.toString() ?? '');

        isOnline = other['isOnline'] == true;
      } catch (_) {
        name = 'Unknown';
        avatar = '';
        isOnline = false;
      }
      groupId = '';
    }

    // Safely parse lastMessage — it could be a Map or a String
    final rawLastMessage = chat['lastMessage'];
    Map<String, dynamic>? lastMessage;
    if (rawLastMessage is Map) {
      lastMessage = Map<String, dynamic>.from(rawLastMessage);
    }
    final unreadCount = chat['unreadCount'] ?? 0;

    String lastMsgText = '';
    String timeText = '';

    if (lastMessage != null) {
      final type = (lastMessage['type'] ?? 'text').toString();
      if (type == 'text' || type == 'system') {
        lastMsgText = (lastMessage['content'] ?? '').toString();
      } else if (type == 'revoked') {
        lastMsgText = 'This message was deleted';
      } else {
        lastMsgText = _mediaLabel(type);
      }

      // Try createdAt from lastMessage, fallback to chat's lastMessageAt
      final createdAt = lastMessage['createdAt'] ?? chat['lastMessageAt'];
      if (createdAt != null) {
        timeText = _formatTime(createdAt.toString());
      }
    }

    // Safely check if current user sent the last message
    bool isMyLastMessage = false;
    if (lastMessage != null) {
      final senderId = lastMessage['senderId'];
      if (senderId is Map) {
        isMyLastMessage = senderId['_id']?.toString() == currentUserId;
      } else if (senderId is String) {
        isMyLastMessage = senderId == currentUserId;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            InfexorPageRoute(
              page: ConversationScreen(
                chatId: chat['_id']?.toString() ?? '',
                chatName: name,
                chatAvatar: avatar,
                isOnline: isOnline,
                isGroup: isGroup,
                groupId: groupId,
              ),
            ),
          ).then((_) => onReturn?.call());
        },
        onLongPress: () => _showChatOptions(context, name),
        splashFactory: InkRipple.splashFactory,
        highlightColor: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: isDark
                        ? AppColors.darkBgSecondary
                        : AppColors.bgCard,
                    backgroundImage: avatar.isNotEmpty
                        ? CachedNetworkImageProvider(
                            UrlUtils.getFullUrl(avatar),
                          )
                        : null,
                    child: avatar.isEmpty
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: subtitleColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.online,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Name + last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (timeText.isNotEmpty)
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0
                                  ? AppColors.badgeBg
                                  : subtitleColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Message status ticks
                        if (isMyLastMessage)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _StatusIcon(
                              status: (lastMessage?['status'] ?? 'sent')
                                  .toString(),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            lastMsgText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: const BoxDecoration(
                              color: AppColors.badgeBg, // Blue Badge
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChatOptions(BuildContext context, String chatName) {
    final unreadCount = chat['unreadCount'] ?? 0;
    final theme = Theme.of(context);
    final sheetBg = theme.scaffoldBackgroundColor;
    final sheetText = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final sheetIcon = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: sheetIcon,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  chatName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: sheetText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.push_pin_outlined, color: sheetIcon),
                title: Text('Pin chat', style: TextStyle(color: sheetText)),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.volume_off_outlined, color: sheetIcon),
                title: Text(
                  'Mute notifications',
                  style: TextStyle(color: sheetText),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              ListTile(
                leading: Icon(Icons.archive_outlined, color: sheetIcon),
                title: Text('Archive chat', style: TextStyle(color: sheetText)),
                onTap: () => Navigator.pop(ctx),
              ),
              if (unreadCount > 0)
                ListTile(
                  leading: Icon(
                    Icons.mark_chat_read_outlined,
                    color: sheetIcon,
                  ),
                  title: Text(
                    'Mark as read',
                    style: TextStyle(color: sheetText),
                  ),
                  onTap: () => Navigator.pop(ctx),
                )
              else
                ListTile(
                  leading: Icon(
                    Icons.mark_chat_unread_outlined,
                    color: sheetIcon,
                  ),
                  title: Text(
                    'Mark as unread',
                    style: TextStyle(color: sheetText),
                  ),
                  onTap: () => Navigator.pop(ctx),
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFE53935),
                ),
                title: const Text(
                  'Delete chat',
                  style: TextStyle(color: Color(0xFFE53935)),
                ),
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  String _mediaLabel(String type) {
    switch (type) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎥 Video';
      case 'audio':
      case 'voice':
        return '🎤 Voice message';
      case 'document':
        return '📄 Document';
      case 'location':
        return '📍 Location';
      case 'contact':
        return '👤 Contact';
      case 'gif':
        return 'GIF';
      default:
        return type;
    }
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) {
        return DateFormat.jm().format(date);
      } else if (diff.inDays == 1) {
        return 'Yesterday';
      } else if (diff.inDays < 7) {
        return DateFormat.E().format(date);
      } else {
        return DateFormat('dd/MM/yy').format(date);
      }
    } catch (_) {
      return '';
    }
  }
}

class _StatusIcon extends StatelessWidget {
  final String status;
  const _StatusIcon({required this.status});

  @override
  Widget build(BuildContext context) {
    final tickColor =
        Theme.of(context).textTheme.bodyMedium?.color ??
        const Color(0xFF667781);
    switch (status) {
      case 'read':
        return const Icon(Icons.done_all, size: 16, color: Color(0xFF53BDEB));
      case 'delivered':
        return Icon(Icons.done_all, size: 16, color: tickColor);
      case 'sent':
        return Icon(Icons.done, size: 16, color: tickColor);
      default:
        return Icon(Icons.access_time, size: 14, color: tickColor);
    }
  }
}

class ChatSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> chats;
  final String currentUserId;
  final Box? contactsBox;

  ChatSearchDelegate({
    required this.chats,
    required this.currentUserId,
    this.contactsBox,
  });

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final results = chats.where((chat) {
      final name = _getChatName(chat).toLowerCase();
      return name.contains(query.toLowerCase());
    }).toList();

    if (results.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        return _ChatTile(
          chat: results[index],
          currentUserId: currentUserId,
          contactsBox: contactsBox,
        );
      },
    );
  }

  String _getChatName(Map<String, dynamic> chat) {
    final isGroup = chat['type'] == 'group';
    if (isGroup) {
      final groupData = chat['groupId'];
      return (groupData is Map ? groupData['name'] : 'Group').toString();
    }

    // 1:1
    try {
      final participants = chat['participants'];
      if (participants is List) {
        // Find other participant
        final other = participants.firstWhere(
          (p) => p is Map && p['_id'] != currentUserId,
          orElse: () => null,
        );

        if (other != null) {
          final otherId = other['_id']?.toString();
          if (otherId != null && contactsBox != null && contactsBox!.isOpen) {
            final saved = contactsBox!.get(otherId)?.toString();
            if (saved != null) return saved;
          }
          // Show phone number for unsaved contacts
          final phone = other['phone']?.toString();
          return phone ?? (other['name'] ?? 'Unknown').toString();
        }
      }
    } catch (_) {}
    return 'Unknown';
  }
}
