import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme mode (light/dark/system) with local persistence.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  /// Light until the officer says otherwise.
  ///
  /// Following the system would hand a first-time user whatever their phone
  /// happened to be set to, and a dark public-records screen in bright
  /// outdoor light is the harder read of the two. Dark and system are both a
  /// tap away in the profile menu, and the choice persists once made.
  static const ThemeMode _default = ThemeMode.light;

  ThemeMode _themeMode = _default;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (e) => e.name == value,
        orElse: () => _default,
      );
      notifyListeners();
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLight => _themeMode == ThemeMode.light;
  bool get isSystem => _themeMode == ThemeMode.system;
}
