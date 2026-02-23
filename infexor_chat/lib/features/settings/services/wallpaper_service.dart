import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the WallpaperService
final wallpaperServiceProvider = Provider<WallpaperService>((ref) {
  return WallpaperService();
});

class WallpaperService {
  static const String _boxName = 'settings';
  static const String _defaultWallpaperKey = 'default_wallpaper';
  static const String _chatWallpapersKey = 'chat_wallpapers';

  // List of available wallpapers in assets
  final List<String> availableWallpapers = [
    'assets/images/wallpapers/chatwallpaper.jpg', // Original default
    'assets/images/wallpapers/chatlist_wallpaper.jpg', // Chat list default
    'assets/images/wallpapers/chatlist.jpg',
    'assets/images/wallpapers/chatlist2.jpg',
    'assets/images/wallpapers/ddcdsc.jpg',
    'assets/images/wallpapers/download (1).jpg',
    'assets/images/wallpapers/download (2).jpg',
    'assets/images/wallpapers/download.jpg',
    'assets/images/wallpapers/Gummy Bear Phone Wallpaper.jpg',
  ];

  Future<Box> _getBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  /// Get the global default wallpaper
  Future<String> getDefaultWallpaper() async {
    final box = await _getBox();
    return box.get(
      _defaultWallpaperKey,
      defaultValue: 'assets/images/wallpapers/chatwallpaper.jpg',
    );
  }

  /// Set the global default wallpaper
  Future<void> setDefaultWallpaper(String path) async {
    final box = await _getBox();
    await box.put(_defaultWallpaperKey, path);
  }

  /// Get the wallpaper for a specific chat
  /// Returns null if no specific wallpaper is set for this chat
  Future<String?> getChatWallpaper(String chatId) async {
    final box = await _getBox();
    final Map<dynamic, dynamic> chatWallpapers = box.get(
      _chatWallpapersKey,
      defaultValue: {},
    );
    return chatWallpapers[chatId] as String?;
  }

  /// Set the wallpaper for a specific chat
  Future<void> setChatWallpaper(String chatId, String path) async {
    final box = await _getBox();
    final Map<dynamic, dynamic> chatWallpapers = Map.from(
      box.get(_chatWallpapersKey, defaultValue: {}),
    );
    chatWallpapers[chatId] = path;
    await box.put(_chatWallpapersKey, chatWallpapers);
  }

  /// Remove specific wallpaper for a chat (revert to default)
  Future<void> removeChatWallpaper(String chatId) async {
    final box = await _getBox();
    final Map<dynamic, dynamic> chatWallpapers = Map.from(
      box.get(_chatWallpapersKey, defaultValue: {}),
    );
    chatWallpapers.remove(chatId);
    await box.put(_chatWallpapersKey, chatWallpapers);
  }

  /// Get the effective wallpaper for a chat (specific > global default)
  Future<String> getEffectiveWallpaper(String chatId) async {
    final specific = await getChatWallpaper(chatId);
    if (specific != null) return specific;
    return await getDefaultWallpaper();
  }
}
