import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(() {
  return LocaleNotifier();
});

class LocaleNotifier extends Notifier<Locale> {
  static const String _boxName = 'settings_box';
  static const String _key = 'selected_locale';

  @override
  Locale build() {
    _loadLocale();
    return const Locale('en');
  }

  Future<void> _loadLocale() async {
    final box = await Hive.openBox(_boxName);
    final languageCode = box.get(_key, defaultValue: 'en');
    state = Locale(languageCode);
  }

  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);
    final box = await Hive.openBox(_boxName);
    await box.put(_key, languageCode);
  }
}
