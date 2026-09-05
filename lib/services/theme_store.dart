import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// Persists the theme preference (mirrors web `localStorage['aquila-theme']`) and
/// notifies listeners for live toggle without restart.
class ThemeStore {
  static const String _key = AppConfig.prefTheme;
  static final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getString(_key) != 'light';
    notifier.value = dark;
    return dark;
  }

  Future<void> save(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dark ? 'dark' : 'light');
    notifier.value = dark;
  }
}