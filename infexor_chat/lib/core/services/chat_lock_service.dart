import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

/// Per-chat lock: a chat marked locked requires a biometric / device-credential
/// unlock before its contents are shown. The locked set is stored locally only
/// (never leaves the device).
class ChatLockService {
  static const String boxName = 'locked_chats';
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Open the Hive box. Call once at startup so [isLocked] can read synchronously.
  static Future<void> init() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
  }

  static bool isLocked(String chatId) {
    if (!Hive.isBoxOpen(boxName)) return false;
    return Hive.box(boxName).get(chatId, defaultValue: false) == true;
  }

  static Future<void> setLocked(String chatId, bool locked) async {
    await init();
    final box = Hive.box(boxName);
    if (locked) {
      await box.put(chatId, true);
    } else {
      await box.delete(chatId);
    }
  }

  /// Prompt the device unlock. Returns true when authenticated.
  ///
  /// If the device has no secure lock configured we return true (allow) so a
  /// user can never be permanently trapped out of their own chat.
  static Future<bool> authenticate() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return true;
      return await _auth.authenticate(
        localizedReason: 'Unlock this chat',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      // Misconfigured / unavailable auth → fail open rather than trap the user.
      return true;
    }
  }
}
