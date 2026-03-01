import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/url_utils.dart';
import '../../../core/utils/animated_page_route.dart';
import '../../auth/providers/auth_provider.dart';
import '../../chat/screens/image_viewer_screen.dart';

class ProfileEditScreen extends ConsumerStatefulWidget {
  final bool isTab;
  final VoidCallback? onSave;
  const ProfileEditScreen({super.key, this.isTab = false, this.onSave});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _aboutController = TextEditingController();
  String _avatar = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController.text = user?['name'] ?? '';
    _aboutController.text = user?['about'] ?? '';
    _avatar = UrlUtils.getFullUrl(user?['avatar'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 100,
    );

    if (picked == null) return;

    // Upload the image
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.uploadFile(
        ApiEndpoints.uploadImage,
        picked.path,
        field: 'image',
      );
      final data = response.data;
      final urlPath = data['data']?['url'] ?? data['url'] ?? '';
      if (urlPath.isNotEmpty) {
        setState(() => _avatar = UrlUtils.getFullUrl(urlPath));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name is required'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final success = await ref
        .read(authProvider.notifier)
        .updateProfile(
          name: _nameController.text.trim(),
          about: _aboutController.text.trim(),
          avatar: _avatar,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile updated')));
        if (widget.onSave != null) {
          widget.onSave!();
        } else if (!widget.isTab) {
          Navigator.pop(context);
        }
      } else {
        final error = ref.read(authProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'Failed to update profile'),
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
    final bgColor = theme.scaffoldBackgroundColor;
    final textColor =
        theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : Colors.black);
    final subtitleColor =
        theme.textTheme.bodyMedium?.color ??
        (isDark ? Colors.grey[400]! : Colors.grey);
    final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;
    final borderColor = isDark ? AppColors.darkBgSecondary : AppColors.border;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: IconThemeData(color: textColor),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentBlue,
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: AppColors.accentBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Avatar
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_avatar.isNotEmpty) {
                        Navigator.push(
                          context,
                          ScaleFadePageRoute(
                            builder: (_) => ImageViewerScreen(
                              imageUrl: _avatar,
                              senderName: _nameController.text.trim(),
                            ),
                          ),
                        );
                      }
                    },
                    child: Hero(
                      tag: 'profile_avatar',
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkBgSecondary
                              : AppColors.bgHover,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: _avatar.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _avatar,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.accentBlue,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 48,
                                    color: subtitleColor,
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 48,
                                  color: subtitleColor,
                                ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.accentBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: bgColor, width: 3),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Name field
            TextField(
              controller: _nameController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: subtitleColor),
                prefixIcon: Icon(Icons.person_outline, color: subtitleColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.accentBlue),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cardColor,
              ),
              maxLength: 50,
            ),

            const SizedBox(height: 16),

            // About field
            TextField(
              controller: _aboutController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'About',
                labelStyle: TextStyle(color: subtitleColor),
                prefixIcon: Icon(Icons.info_outline, color: subtitleColor),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: AppColors.accentBlue),
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: cardColor,
              ),
              maxLength: 150,
            ),
          ],
        ),
      ),
    );
  }
}
