import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/theme_provider.dart';

class MpladSatyaApp extends StatefulWidget {
  const MpladSatyaApp({super.key});

  @override
  State<MpladSatyaApp> createState() => _MpladSatyaAppState();
}

class _MpladSatyaAppState extends State<MpladSatyaApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    // Built once against the live AuthProvider: the router listens to it for
    // redirects, so rebuilding it here would drop the navigation stack.
    _router ??= AppRouter.build(context.read<AuthProvider>());

    return Consumer2<ThemeProvider, LocaleProvider>(
      builder: (context, themeProvider, localeProvider, _) {
        return MaterialApp.router(
          title: 'MPLAD SATYA',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: _router!,
          builder: (context, child) {
            // Clamp system font scaling.
            //
            // Android lets a user set text up to ~2x, and government officers
            // routinely do. Unclamped, every fixed-height row, stat tile and
            // badge in the app overflows its box - which is exactly what was
            // reported from a real device.
            //
            // Clamping rather than ignoring: accessibility scaling still works
            // up to 1.3x, which covers the large-text setting most people
            // actually use, while the layout stays inside its boxes. Beyond
            // that the correct answer is a reflowed layout, not a burst one.
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: media.textScaler.clamp(
                  minScaleFactor: 1.0,
                  maxScaleFactor: 1.3,
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}
