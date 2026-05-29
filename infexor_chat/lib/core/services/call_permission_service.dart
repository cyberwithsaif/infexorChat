import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Makes sure the device will actually *ring* for incoming voice/video calls
/// when the app is killed or the screen is locked.
///
/// Two modern-Android gates silently break this:
///   • Android 14 (API 34) requires the full-screen-intent permission before
///     a call notification can launch the full-screen ringing UI. Without it
///     the call shows as a quiet notification (or nothing on the lock screen).
///   • Battery optimization can delay/drop the high-priority call FCM in Doze.
///
/// We ask once, with a short rationale, and only when something is missing.
class CallPermissionService {
  static const MethodChannel _channel = MethodChannel(
    'com.infexor.infexor_chat/calls',
  );
  static const String _promptedKey = 'call_perm_prompted_v1';

  static Future<bool> canUseFullScreenIntent() async {
    try {
      return await _channel.invokeMethod<bool>('canUseFullScreenIntent') ??
          true;
    } catch (_) {
      return true; // older Android / non-Android → always allowed
    }
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Safe to call on every launch — self-gates with a Hive flag and only
  /// prompts when a relevant permission is actually missing.
  static Future<void> ensureCallReadiness(BuildContext context) async {
    final Box box;
    try {
      box = Hive.isBoxOpen('settings')
          ? Hive.box('settings')
          : await Hive.openBox('settings');
    } catch (_) {
      return;
    }
    if (box.get(_promptedKey) == true) return;

    final fsiOk = await canUseFullScreenIntent();
    final batteryOk = await isIgnoringBatteryOptimizations();
    if (fsiOk && batteryOk) return; // nothing to ask
    if (!context.mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Don't miss calls"),
        content: const Text(
          'To ring for voice and video calls when Infexor is closed or your '
          'screen is locked, allow it to show full-screen call alerts and keep '
          'running in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Allow'),
          ),
        ],
      ),
    );

    // Only ask once automatically; the user can re-enable later from settings.
    await box.put(_promptedKey, true);
    if (proceed != true) return;

    // Open the full-screen-intent settings page first (it lands underneath),
    // then fire the battery-exemption dialog (it appears on top first).
    if (!fsiOk) {
      await _channel.invokeMethod('openFullScreenIntentSettings');
    }
    if (!batteryOk) {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    }
  }
}
