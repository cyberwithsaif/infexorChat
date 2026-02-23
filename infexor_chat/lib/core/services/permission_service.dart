import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class PermissionService {
  /// Request all essential permissions at once
  static Future<void> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.contacts,
      Permission.camera,
      Permission.microphone,
      Permission.storage, // For older Android
      Permission.photos, // For Android 13+
      Permission.videos, // For Android 13+
      Permission.audio, // For Android 13+
      Permission.notification,
    ].request();

    // Log results (optional)
    statuses.forEach((permission, status) {
      debugPrint('Permission $permission: $status');
    });

    // Request battery optimization exemption for background service survival
    await requestBatteryOptimizationExemption();
  }

  /// Request a specific permission
  static Future<bool> requestPermission(Permission permission) async {
    final status = await permission.request();
    return status.isGranted;
  }

  /// Check if a specific permission is granted
  static Future<bool> isGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Request battery optimization exemption (Android only)
  /// This is critical for keeping the background service alive when the app
  /// is removed from recents on aggressive OEM Android skins (Xiaomi, Samsung, etc.)
  static Future<void> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;

    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (!status.isGranted) {
        final result = await Permission.ignoreBatteryOptimizations.request();
        debugPrint('Battery optimization exemption: $result');
      } else {
        debugPrint('Battery optimization already exempted');
      }
    } catch (e) {
      debugPrint('Error requesting battery optimization exemption: $e');
    }
  }
}
