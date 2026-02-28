import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

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
}
