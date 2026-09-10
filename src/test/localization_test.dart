import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mplad_satya/l10n/app_localizations.dart';
import 'package:mplad_satya/providers/locale_provider.dart';

/// The app must never offer a language it cannot actually render.
///
/// Seven partial translation maps (11-25 % coverage) live in
/// app_localizations.dart as a starting point for translators. These tests
/// make it impossible to advertise one before it is finished.
void main() {
  final strings = AppLocalizations.localizedStringsForTest;
  final englishKeys = strings['en']!.keys.toSet();

  group('advertised locales', () {
    test('every advertised locale is 100% translated', () {
      for (final locale in AppLocalizations.supportedLocales) {
        final map = strings[locale.languageCode];
        expect(map, isNotNull,
            reason: '${locale.languageCode} is advertised but has no map');

        final missing = englishKeys.difference(map!.keys.toSet());
        expect(missing, isEmpty,
            reason: '${locale.languageCode} is advertised but is missing '
                '${missing.length} of ${englishKeys.length} strings: '
                '${missing.take(5).toList()}');
      }
    });

    test('no advertised locale has an empty translation', () {
      for (final locale in AppLocalizations.supportedLocales) {
        strings[locale.languageCode]!.forEach((key, value) {
          expect(value.trim(), isNotEmpty,
              reason: '${locale.languageCode}.$key is blank');
        });
      }
    });

    test('the picker and the delegate agree', () {
      final picker = LocaleProvider.supportedLocales.keys.toSet();
      final delegate =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      expect(picker, equals(delegate),
          reason: 'a language in the picker that the delegate does not support '
              'renders as English under a non-English label');
    });

    test('English and Hindi are available', () {
      final codes =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
      expect(codes, containsAll(<String>['en', 'hi']));
    });
  });

  group('withheld locales', () {
    test('incomplete maps exist but are NOT advertised', () {
      final advertised =
          AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();

      for (final code in AppLocalizations.allLocaleCodes) {
        final map = strings[code];
        if (map == null) continue;
        final complete = englishKeys.difference(map.keys.toSet()).isEmpty;
        if (!complete) {
          expect(advertised, isNot(contains(code)),
              reason: '$code is only '
                  '${(100 * map.length / englishKeys.length).round()}% '
                  'translated and must not be selectable');
        }
      }
    });

    test('an unsupported code still resolves via English fallback', () {
      // A device set to Bengali must render readable English, not blank keys.
      final l10n = AppLocalizations(const Locale('bn'));
      expect(l10n.get('signIn'), isNotEmpty);
      expect(l10n.get('signIn'), isNot('signIn'));
    });
  });
}
