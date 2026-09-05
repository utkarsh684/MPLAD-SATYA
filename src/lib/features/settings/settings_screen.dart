import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/theme_provider.dart';
import '../../providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        children: [
          _buildSectionHeader(context, l10n.account),
          _buildProfileTile(context),
          
          _buildSectionHeader(context, l10n.appearance),
          _buildThemeSelector(context),
          
          _buildSectionHeader(context, l10n.language),
          _buildLanguageSelector(context),
          
          _buildSectionHeader(context, l10n.notifications),
          SwitchListTile(
            title: Text(l10n.highRiskAlerts, style: GoogleFonts.inter()),
            value: true,
            onChanged: (val) {},
          ),
          SwitchListTile(
            title: Text(l10n.investigationReminders, style: GoogleFonts.inter()),
            value: true,
            onChanged: (val) {},
          ),
          
          _buildSectionHeader(context, l10n.data),
          ListTile(
            leading: const Icon(Icons.offline_bolt_outlined),
            title: Text(l10n.offlineData, style: GoogleFonts.inter()),
            subtitle: Text('42 MB used', style: GoogleFonts.inter(fontSize: 12)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.clearDemoData, style: GoogleFonts.inter()),
            onTap: () {},
          ),
          
          const SizedBox(height: 32),
          Center(
            child: Text(
              'MPLAD SATYA\nSIH26102 • v1.0.0',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 16),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildProfileTile(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const CircleAvatar(
        child: Icon(Icons.person),
      ),
      title: Text('Demo Officer', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      subtitle: Text('${l10n.department} of Planning\nLucknow ${l10n.district}', style: GoogleFonts.inter(fontSize: 12)),
      isThreeLine: true,
    );
  }

  Widget _buildThemeSelector(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        RadioListTile<ThemeMode>(
          title: Text(l10n.lightMode, style: GoogleFonts.inter()),
          value: ThemeMode.light,
          groupValue: themeProvider.themeMode,
          onChanged: (val) => themeProvider.setThemeMode(val!),
        ),
        RadioListTile<ThemeMode>(
          title: Text(l10n.darkMode, style: GoogleFonts.inter()),
          value: ThemeMode.dark,
          groupValue: themeProvider.themeMode,
          onChanged: (val) => themeProvider.setThemeMode(val!),
        ),
        RadioListTile<ThemeMode>(
          title: Text(l10n.systemDefault, style: GoogleFonts.inter()),
          value: ThemeMode.system,
          groupValue: themeProvider.themeMode,
          onChanged: (val) => themeProvider.setThemeMode(val!),
        ),
      ],
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();

    return Column(
      children: LocaleProvider.locales.map((locale) {
        return RadioListTile<Locale>(
          title: Text(LocaleProvider.supportedLocales[locale.languageCode]!, style: GoogleFonts.inter()),
          value: locale,
          groupValue: localeProvider.locale,
          onChanged: (val) => localeProvider.setLocale(val!),
        );
      }).toList(),
    );
  }
}
