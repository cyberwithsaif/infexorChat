import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/wallpaper_provider.dart';

class WallpaperSelectionScreen extends ConsumerWidget {
  final String? chatId; // If null, setting default wallpaper

  const WallpaperSelectionScreen({super.key, this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(wallpaperServiceProvider);
    final wallpapers = service.availableWallpapers;

    // Determine current wallpaper to show selection
    final currentWallpaperAsync = chatId != null
        ? ref.watch(chatWallpaperProvider(chatId!))
        : ref.watch(defaultWallpaperProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(chatId != null ? 'Chat Wallpaper' : 'Default Wallpaper'),
        actions: [
          if (chatId != null)
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset to Default',
              onPressed: () {
                ref
                    .read(wallpaperControllerProvider.notifier)
                    .removeChatWallpaper(chatId!);
                Navigator.pop(context);
              },
            ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.6,
        ),
        itemCount: wallpapers.length,
        itemBuilder: (context, index) {
          final path = wallpapers[index];
          final isSelected = currentWallpaperAsync.value == path;

          return GestureDetector(
            onTap: () {
              // Show loading? Or just set and pop
              if (chatId != null) {
                ref
                    .read(wallpaperControllerProvider.notifier)
                    .setChatWallpaper(chatId!, path);
              } else {
                ref
                    .read(wallpaperControllerProvider.notifier)
                    .setDefaultWallpaper(path);
              }
              Navigator.pop(context); // Go back after selection
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: Colors.grey,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      color: Colors.black.withValues(alpha: 0.4),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
