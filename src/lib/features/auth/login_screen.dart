import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../widgets/app_logo.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/locale_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _officerIdController = TextEditingController(text: 'OFF-001');
  final _passwordController = TextEditingController(text: '********');

  @override
  void dispose() {
    _officerIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleDemoLogin() {
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Top Language Selector (for demo)
                Align(
                  alignment: Alignment.topRight,
                  child: _buildLanguageSelector(context),
                ),
                const SizedBox(height: 20),
                
                // Logo & Header
                AppLogo(size: 64, light: isDark),
                const SizedBox(height: 12),
                Text(
                  l10n.appSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 48),

                // Login Box
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.signIn,
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: theme.textTheme.displayLarge?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // Officer ID
                      TextField(
                        controller: _officerIdController,
                        decoration: InputDecoration(
                          labelText: l10n.officerId,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Password
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.password,
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Login Button (Normal)
                      ElevatedButton(
                        onPressed: _handleDemoLogin,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(l10n.signIn),
                      ),
                      const SizedBox(height: 16),
                      
                      // Demo Officer Button
                      OutlinedButton.icon(
                        onPressed: _handleDemoLogin,
                        icon: const Icon(Icons.science_outlined),
                        label: Text(l10n.continueAsDemo),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: AppColors.saffronDark,
                          side: const BorderSide(color: AppColors.saffronDark),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Footer
                Text(
                  'SIH26102 • v1.0.0',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return DropdownButtonHideUnderline(
          child: DropdownButton<Locale>(
            value: localeProvider.locale,
            icon: const Icon(Icons.language_rounded, size: 20),
            alignment: Alignment.centerRight,
            items: LocaleProvider.locales.map((locale) {
              return DropdownMenuItem(
                value: locale,
                child: Text(
                  LocaleProvider.supportedLocales[locale.languageCode]!,
                  style: GoogleFonts.inter(fontSize: 13),
                ),
              );
            }).toList(),
            onChanged: (newLocale) {
              if (newLocale != null) {
                localeProvider.setLocale(newLocale);
              }
            },
          ),
        );
      },
    );
  }
}
