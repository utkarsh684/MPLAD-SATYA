import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages locale selection with local persistence.
class LocaleProvider extends ChangeNotifier {
  static const String _key = 'locale_code';

  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  /// Locales whose translation is complete, with native display names.
  ///
  /// Deliberately two entries, not nine. Seven further language maps exist in
  /// `app_localizations.dart` at 11-25 % coverage; offering them would give an
  /// officer a mostly-English screen under a Bengali or Tamil label. A locale
  /// is added here only once its map is complete, and
  /// `test/localization_test.dart` fails the build if this list ever runs
  /// ahead of the translations.
  static const Map<String, String> supportedLocales = {
    'en': 'English',
    'hi': 'हिन्दी',
  };

  static List<Locale> get locales =>
      supportedLocales.keys.map((code) => Locale(code)).toList();

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    if (code != null && supportedLocales.containsKey(code)) {
      _locale = Locale(code);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }

  String get currentLanguageName =>
      supportedLocales[_locale.languageCode] ?? 'English';
}
