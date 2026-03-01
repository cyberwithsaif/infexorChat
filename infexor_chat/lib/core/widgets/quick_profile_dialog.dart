import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_colors.dart';
import '../utils/url_utils.dart';
import '../../../config/routes.dart';

class QuickProfileDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final String chatId;
  final String displayName;
  final String avatarUrl;

  const QuickProfileDialog({
    super.key,
    required this.user,
    required this.chatId,
    required this.displayName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final imageSize = MediaQuery.of(context).size.width * 0.65;
    final fullAvatar = UrlUtils.getFullUrl(avatarUrl);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Photo & Name Overlay
          Stack(
            children: [
              Container(
                width: imageSize,
                height: imageSize,
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  image: fullAvatar.isNotEmpty
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(fullAvatar),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: fullAvatar.isEmpty
                    ? Center(
                        child: Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: imageSize * 0.4,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : null,
              ),
              // Name Overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent],
                    ),
                  ),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Action Bar
          Container(
            width: imageSize,
            height: 48,
            color: isDark ? AppColors.darkBgSecondary : Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.chat_bubble_outline,
                  onTap: () {
                    Navigator.pop(context);
                    router.push(
                      '/chat/$chatId',
                      extra: {
                        'chatName': displayName,
                        'chatAvatar': avatarUrl,
                        'isOnline': user['isOnline'] == true,
                      },
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.call_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    router.push(
                      '/call',
                      extra: {
                        'chatId': chatId,
                        'userId': user['_id']?.toString() ?? '',
                        'callerName': displayName,
                        'callerAvatar': avatarUrl,
                        'isVideoCall': false,
                        'isIncoming': false,
                      },
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.videocam_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    router.push(
                      '/call',
                      extra: {
                        'chatId': chatId,
                        'userId': user['_id']?.toString() ?? '',
                        'callerName': displayName,
                        'callerAvatar': avatarUrl,
                        'isVideoCall': true,
                        'isIncoming': false,
                      },
                    );
                  },
                ),
                _ActionButton(
                  icon: Icons.info_outline,
                  onTap: () {
                    Navigator.pop(context);
                    router.push(
                      '/profile',
                      extra: {
                        'user': user,
                        'chatId': chatId,
                        'contactName': displayName != 'Unknown Caller'
                            ? displayName
                            : null,
                      },
                    );
                  },
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
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.accentBlue, size: 24),
        ),
      ),
    );
  }
}
