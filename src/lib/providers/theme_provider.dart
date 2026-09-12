import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages theme mode (light/dark/system) with local persistence.
class ThemeProvider extends ChangeNotifier {
  static const String _key = 'theme_mode';

  /// Follow the device until the officer says otherwise.
  ///
  /// Someone who has set their phone to dark has already stated a preference,
  /// and overriding it on first launch ignores an answer they gave once for
  /// every app. Light and dark are both a tap away in the profile menu, and
  /// an explicit choice here persists over the system setting.
  static const ThemeMode _default = ThemeMode.system;

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
