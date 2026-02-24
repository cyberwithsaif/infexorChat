import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final themeProvider = NotifierProvider<ThemeNotifier, ThemeMode>(
  ThemeNotifier.new,
);

class ThemeNotifier extends Notifier<ThemeMode> {
  static const _boxName = 'settings';
  static const _themeKey = 'themeMode';

  @override
  ThemeMode build() {
    // Return system as default if the box isn't ready or value missing
    if (!Hive.isBoxOpen(_boxName)) return ThemeMode.light;

    final box = Hive.box(_boxName);
    final themeIndex = box.get(_themeKey, defaultValue: ThemeMode.light.index);
    return ThemeMode.values[themeIndex];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final box = Hive.box(_boxName);
    await box.put(_themeKey, mode.index);
  }
}
