import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../../core/utils/animation_helpers.dart';
import '../../../core/utils/url_utils.dart';
import '../providers/contact_provider.dart';
import '../services/contact_service.dart';
import '../../chat/services/chat_service.dart';
import '../../chat/screens/conversation_screen.dart';
import '../../auth/providers/auth_provider.dart';

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Sync contacts on first load
    Future.microtask(() => ref.read(contactProvider.notifier).syncContacts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _inviteContact() {
    SharePlus.instance.share(
      ShareParams(
        text:
            'Hey! Join me on Infexor Chat. Download now: https://infexor.chat/download',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactState = ref.watch(contactProvider);
    final contacts = contactState.registeredContacts.where((c) {
      if (_searchQuery.isEmpty) return true;
      final name = (c['name'] ?? c['serverName'] ?? '')
          .toString()
          .toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Contact'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(contactProvider.notifier).syncContacts(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              decoration: InputDecoration(
                hintText: 'Search contacts...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Body
          Expanded(child: _buildBody(contactState, contacts)),
        ],
      ),
    );
  }

  void _showDirectChatDialog() {
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final bgColor = theme.scaffoldBackgroundColor;
        final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
        final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
        return AlertDialog(
          backgroundColor: bgColor,
          title: Text('Direct Chat', style: TextStyle(color: textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter phone number with country code to start a chat.',
                style: TextStyle(color: subtitleColor, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: '+919876543210',
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _startDirectChat(phoneController.text.trim());
              },
              child: const Text('Chat'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startDirectChat(String phone) async {
    if (phone.isEmpty) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      ),
    );

    try {
      // 1. Find user by phone
      final user = await ref
          .read(contactServiceProvider)
          .findUserByPhone(phone);

      if (user != null) {
        // 2. Create/Get chat
        // We need ChatService for this.
        // Assuming ChatService is available via a provider or we can access it using ref calls contextually if needed.
        // But better to import it properly.
        // Since I can't easily add import at top right now without reading whole file again,
        // I will rely on reading providers.
        // Let's assume chatServiceProvider is available.
        // 2. Create/Get chat
        final chatRes = await ref
            .read(chatServiceProvider)
            .createChat(user['_id']);

        // Response structure: { success: true, data: { chat: { _id: ... } } }
        final chatData = chatRes['data'];
        final chat = chatData['chat'];

        if (chat == null || chat['_id'] == null) {
          throw Exception('Invalid chat data received');
        }

        if (!mounted) return;
        Navigator.pop(context); // Hide loading

        // 3. Navigate to chat (Replace so back goes to Chat List like WhatsApp)
        final rawParticipants = chat['participants'] ?? [];
        final participants = <Map<String, dynamic>>[];
        for (final p in rawParticipants) {
          if (p is Map) {
            participants.add(Map<String, dynamic>.from(p));
          }
        }
        final currentUserId = ref.read(authProvider).user?['_id'];
        final other = participants.firstWhere(
          (p) => p['_id'] != currentUserId,
          orElse: () => <String, dynamic>{
            'name': 'Unknown',
            'avatar': '',
            'isOnline': false,
          },
        );

        Navigator.pushReplacement(
          context,
          AnimatedPageRoute(
            builder: (_) => ConversationScreen(
              chatId: chat['_id'],
              chatName: other['name'] ?? 'Unknown',
              chatAvatar: other['avatar'] ?? '',
              isOnline: other['isOnline'] ?? false,
              isGroup: false,
              groupId: '',
            ),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.pop(context); // Hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not found on Infexor Chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _onContactTap(Map<String, dynamic> contact) async {
    // Handle both sync response (_id) and getContacts response (contactUserId)
    final userId = contact['contactUserId'] ?? contact['_id'];

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Valid User ID not found')),
      );
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.accentBlue),
      ),
    );

    try {
      // Create/Get chat
      final chatRes = await ref.read(chatServiceProvider).createChat(userId);
      // Response structure: { success: true, data: { chat: { _id: ... } } }
      final chatData = chatRes['data'];
      final chat = chatData['chat'];

      if (chat == null || chat['_id'] == null) {
        throw Exception('Invalid chat data received');
      }

      Navigator.pop(context); // Hide loading

      // Navigate to chat (Replace)
      final name = contact['name']?.toString().isNotEmpty == true
          ? contact['name']
          : contact['serverName']?.toString().isNotEmpty == true
          ? contact['serverName']
          : contact['phone'] ?? 'Unknown';

      Navigator.pushReplacement(
        context,
        AnimatedPageRoute(
          builder: (_) => ConversationScreen(
            chatId: chat['_id'],
            chatName: name,
            chatAvatar: contact['avatar'] ?? '',
            isOnline: contact['isOnline'] ?? false,
            isGroup: false,
            groupId: '',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Hide loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildBody(
    ContactState contactState,
    List<Map<String, dynamic>> contacts,
  ) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    if (contactState.status == ContactSyncStatus.syncing &&
        contactState.registeredContacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.accentBlue),
            const SizedBox(height: 16),
            Text('Syncing contacts...', style: TextStyle(color: subtitleColor)),
          ],
        ),
      );
    }

    if (contactState.status == ContactSyncStatus.noPermission) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.contacts_rounded, size: 64, color: subtitleColor),
              const SizedBox(height: 16),
              Text(
                'Contacts Permission Required',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Allow access to your contacts to find friends on Infexor Chat',
                textAlign: TextAlign.center,
                style: TextStyle(color: subtitleColor),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    ref.read(contactProvider.notifier).syncContacts(),
                child: const Text('Grant Permission'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        // Invite button
        ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
            ),
            child: const Icon(
              Icons.person_add_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          title: Text('Invite friends', style: TextStyle(color: textColor)),
          onTap: _inviteContact,
        ),
        const Divider(height: 1),

        // Registered contacts header
        if (contacts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'CONTACTS ON INFEXOR CHAT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subtitleColor,
                letterSpacing: 0.5,
              ),
            ),
          ),

        // Contact list
        if (contacts.isEmpty && contactState.status == ContactSyncStatus.synced)
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 48,
                  color: subtitleColor,
                ),
                const SizedBox(height: 12),
                Text(
                  'No contacts on Infexor Chat yet',
                  style: TextStyle(color: subtitleColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invite your friends to get started',
                  style: TextStyle(color: subtitleColor, fontSize: 13),
                ),
              ],
            ),
          ),

        ...contacts.asMap().entries.map(
          (entry) => StaggeredListItem(
            index: entry.key,
            child: _ContactTile(
              contact: entry.value,
              onTap: () => _onContactTap(entry.value),
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final Map<String, dynamic> contact;
  final VoidCallback onTap;

  const _ContactTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;

    final displayName = contact['name']?.toString().isNotEmpty == true
        ? contact['name']
        : contact['serverName']?.toString().isNotEmpty == true
        ? contact['serverName']
        : contact['phone'] ?? 'Unknown';

    final about = contact['about'] ?? '';
    final avatar = contact['avatar'] ?? '';
    final isOnline = contact['isOnline'] ?? false;

    return TapScaleFeedback(
      onTap: onTap,
      child: ListTile(
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: isDark
                  ? AppColors.darkBgSecondary
                  : AppColors.bgCard,
              backgroundImage: avatar.toString().isNotEmpty
                  ? CachedNetworkImageProvider(
                      UrlUtils.getFullUrl(avatar.toString()),
                    )
                  : null,
              child: avatar.toString().isEmpty
                  ? Text(
                      displayName.toString().isNotEmpty
                          ? displayName.toString()[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: subtitleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    )
                  : null,
            ),
            if (isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.online,
                    shape: BoxShape.circle,
                    border: Border.all(color: bgColor, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          displayName,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        ),
        subtitle: about.toString().isNotEmpty
            ? Text(
                about,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subtitleColor, fontSize: 13),
              )
            : null,
      ),
    );
  }
}
