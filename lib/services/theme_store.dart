import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// Persists the theme preference (mirrors web `localStorage['aquila-theme']`).
class ThemeStore {
  static const String _key = AppConfig.prefTheme;

  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'dark';
  }

  Future<void> save(bool dark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dark ? 'dark' : 'light');
  }
}