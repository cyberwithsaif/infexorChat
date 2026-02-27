import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';

/// Shows an attachment picker with a circular reveal animation.
///
/// Each grid item triggers a specific callback when tapped:
/// - Camera: Takes a photo via the device camera.
/// - Gallery: Picks images from the device gallery (multi-select).
/// - Video: Picks a video from the device gallery.
/// - Document: Opens a file picker for documents.
/// - Location: Fetches the current GPS position and returns it.
/// - Contact: Placeholder for future contact-sharing functionality.
void showAttachmentPicker(
  BuildContext context, {
  required void Function(XFile image) onCamera,
  required void Function(XFile image) onGallery,
  void Function(List<XFile> images)? onMultiGallery,
  required void Function(XFile video) onVideo,
  required void Function(PlatformFile file) onDocument,
  required void Function(Position position) onLocation,
  required VoidCallback onContact,
}) {
  final imagePicker = ImagePicker();

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      final theme = Theme.of(dialogContext);
      final isDark = theme.brightness == Brightness.dark;
      final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
      final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
      final cardColor = isDark ? AppColors.darkBgSecondary : AppColors.bgCard;

      return SafeArea(
        child: Material(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: subtitleColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Share Content',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                // Options grid - Row 1
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: AppColors.accentBlue,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        final photo = await imagePicker.pickImage(
                          source: ImageSource.camera,
                        );
                        if (photo != null) {
                          onCamera(photo);
                        }
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.photo_rounded,
                      label: 'Gallery',
                      color: AppColors.accentPurple,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        final mediaFiles = await imagePicker.pickMultiImage(
                          imageQuality: 80,
                        );
                        if (mediaFiles.isNotEmpty) {
                          if (onMultiGallery != null) {
                            onMultiGallery(mediaFiles);
                          } else {
                            for (final media in mediaFiles) {
                              onGallery(media);
                            }
                          }
                        }
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.videocam_rounded,
                      label: 'Video',
                      color: AppColors.danger,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        final video = await imagePicker.pickVideo(
                          source: ImageSource.gallery,
                          maxDuration: const Duration(minutes: 5),
                        );
                        if (video != null) {
                          onVideo(video);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Options grid - Row 2
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _AttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'Document',
                      color: AppColors.warning,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.any,
                          allowMultiple: false,
                        );
                        if (result != null && result.files.isNotEmpty) {
                          onDocument(result.files.first);
                        }
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      color: AppColors.success,
                      onTap: () async {
                        Navigator.pop(dialogContext);
                        try {
                          final serviceEnabled =
                              await Geolocator.isLocationServiceEnabled();
                          if (!serviceEnabled) return;

                          var permission = await Geolocator.checkPermission();
                          if (permission == LocationPermission.denied) {
                            permission = await Geolocator.requestPermission();
                            if (permission == LocationPermission.denied) {
                              return;
                            }
                          }
                          if (permission == LocationPermission.deniedForever) {
                            return;
                          }

                          final position = await Geolocator.getCurrentPosition(
                            locationSettings: const LocationSettings(
                              accuracy: LocationAccuracy.high,
                            ),
                          );
                          onLocation(position);
                        } catch (_) {
                          // Location unavailable; silently ignore.
                        }
                      },
                    ),
                    _AttachmentOption(
                      icon: Icons.person_rounded,
                      label: 'Contact',
                      color: AppColors.accentBlue,
                      onTap: () {
                        Navigator.pop(dialogContext);
                        onContact();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedValue = Curves.easeOutCubic.transform(animation.value);

      return Stack(
        fit: StackFit.expand,
        children: [
          // Tap outside to dismiss
          GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
          // Animated content with circular reveal
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipPath(
              clipper: _CircularRevealClipper(fraction: curvedValue),
              child: child,
            ),
          ),
        ],
      );
    },
  );
}

/// Clips content in an expanding circle from the bottom center.
class _CircularRevealClipper extends CustomClipper<Path> {
  final double fraction;

  _CircularRevealClipper({required this.fraction});

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height);
    final maxRadius = sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * fraction;

    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return fraction != oldClipper.fraction;
  }
}

/// A single attachment option shown as a circular icon with a label.
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtitleColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBgSecondary
                    : AppColors.bgSecondary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: subtitleColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
