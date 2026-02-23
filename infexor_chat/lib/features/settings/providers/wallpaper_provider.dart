import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallpaper_service.dart';

// Service Provider
final wallpaperServiceProvider = Provider<WallpaperService>((ref) {
  return WallpaperService();
});

// Default Wallpaper Provider
final defaultWallpaperProvider = FutureProvider<String>((ref) async {
  final service = ref.watch(wallpaperServiceProvider);
  return service.getDefaultWallpaper();
});

// Effective Wallpaper Provider for a specific chat
final chatWallpaperProvider = FutureProvider.family<String, String>((
  ref,
  chatId,
) async {
  final service = ref.watch(wallpaperServiceProvider);
  final specific = await service.getChatWallpaper(chatId);
  if (specific != null) return specific;
  // If no specific wallpaper, use default (and watch it for updates)
  return ref.watch(defaultWallpaperProvider.future);
});

// Controller for mutating wallpaper state
class WallpaperController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // No initialization state needed really
    return null;
  }

  Future<void> setDefaultWallpaper(String path) async {
    final service = ref.read(wallpaperServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await service.setDefaultWallpaper(path);
      ref.invalidate(defaultWallpaperProvider);
    });
  }

  Future<void> setChatWallpaper(String chatId, String path) async {
    final service = ref.read(wallpaperServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await service.setChatWallpaper(chatId, path);
      ref.invalidate(chatWallpaperProvider(chatId));
    });
  }

  Future<void> removeChatWallpaper(String chatId) async {
    final service = ref.read(wallpaperServiceProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await service.removeChatWallpaper(chatId);
      ref.invalidate(chatWallpaperProvider(chatId));
    });
  }
}

final wallpaperControllerProvider =
    AsyncNotifierProvider<WallpaperController, void>(WallpaperController.new);
