import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class BlockedContactsScreen extends ConsumerStatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  ConsumerState<BlockedContactsScreen> createState() =>
      _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends ConsumerState<BlockedContactsScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.get(ApiEndpoints.blockedUsers);
      final data = response.data;
      final blockedData = data is Map ? (data['data'] ?? data) : data;
      setState(() {
        _blocked = List<Map<String, dynamic>>.from(
          (blockedData is Map ? blockedData['blocked'] : blockedData) ?? [],
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _unblockUser(String userId, String name) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          'Unblock',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          'Unblock $name?',
          style: TextStyle(color: subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Unblock',
              style: TextStyle(color: AppColors.accentBlue),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.delete('${ApiEndpoints.blockUser}/$userId');
      _loadBlocked();
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
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
    final bgColor = theme.scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Blocked Contacts',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentBlue),
            )
          : _blocked.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_outlined,
                    size: 64,
                    color: subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No blocked contacts',
                    style: TextStyle(color: subtitleColor, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _blocked.length,
              itemBuilder: (context, index) {
                final user = _blocked[index];
                final name = user['name'] ?? 'Unknown';
                final avatar = user['avatar'] ?? '';
                final userId = user['_id']?.toString() ?? '';

                return ListTile(
                  leading: CircleAvatar(
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
                  title: Text(
                    name,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: TextButton(
                    onPressed: () => _unblockUser(userId, name),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(color: AppColors.accentBlue),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
