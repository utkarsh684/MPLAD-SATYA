import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/outbox_provider.dart';
import '../../providers/server_status_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/settings_controls.dart';
import '../../widgets/tutorial.dart';

/// Real account, real sync state, real server identity.
///
/// Toggles that previously discarded their value are gone: an on-screen switch
/// that does nothing is worse than no switch.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          16,
          Responsive.horizontalPadding(context),
          40,
        ),
        children: [
          _ProfileCard(),

          SettingsGroup(
            title: l10n.appearance,
            icon: Icons.palette_rounded,
            children: [
              SegmentedToggle<ThemeMode>(
                value: context.watch<ThemeProvider>().themeMode,
                onChanged: context.read<ThemeProvider>().setThemeMode,
                options: [
                  SegmentOption(
                      value: ThemeMode.light,
                      label: l10n.lightMode,
                      icon: Icons.light_mode_rounded),
                  SegmentOption(
                      value: ThemeMode.dark,
                      label: l10n.darkMode,
                      icon: Icons.dark_mode_rounded),
                  SegmentOption(
                      value: ThemeMode.system,
                      label: l10n.systemDefault,
                      icon: Icons.brightness_auto_rounded),
                ],
              ),
            ],
          ),

          _LanguageGroup(),

          _SyncGroup(),

          SettingsGroup(
            title: 'Transparency',
            icon: Icons.visibility_rounded,
            footnote:
                'Every rule the engine applies is published, along with the '
                'SHA-256 digest of the exact rulebook this server runs.',
            children: [
              SettingsRow(
                icon: Icons.rule_folder_rounded,
                label: 'Rulebook',
                sublabel: 'Conditions, points and provenance for every rule',
                onTap: () => context.push('/rulebook'),
              ),
              SettingsRow(
                icon: Icons.school_rounded,
                label: 'Replay the guided tour',
                sublabel: 'Offered again next time the dashboard opens',
                showDivider: false,
                onTap: () async {
                  await TourPreference.reset();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'The tour will be offered again on the dashboard.'),
                    ),
                  );
                },
              ),
            ],
          ),

          _ServerGroup(),

          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: auth.busy ? null : () => _confirmSignOut(context, auth),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                const AppLogo(size: 44, showText: false),
                const SizedBox(height: 10),
                Text(
                  'MPLAD SATYA  ·  v1.0.0',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary),
                ),
                Text(
                  'SIH26102  ·  Ministry of Statistics & Programme Implementation',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.textTertiary),
                ),
                if (user != null) ...[
                  const SizedBox(height: 6),
                  Text(user.phoneMasked,
                      style: GoogleFonts.robotoMono(
                          fontSize: 10, color: AppColors.textTertiary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, AuthProvider auth) async {
    final outbox = context.read<OutboxProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        title: const Text('Sign out?'),
        content: Text(
          outbox.hasPending
              ? '${outbox.pendingCount} item(s) have not reached the server yet. '
                  'They stay on this device, but you must sign back in to send them.'
              : 'This revokes every session for your account on all devices.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await auth.signOut();
  }
}

class _ProfileCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.navyLight, AppColors.navy]
              : [AppColors.govBlue, AppColors.govBlueDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Text(
              _initials(user?.displayName ?? '?'),
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? '—',
                  style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.saffron.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    user?.roleLabel ?? '—',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
                if ((user?.districtName ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 13, color: Colors.white70),
                      const SizedBox(width: 4),
                      Text(user!.districtName!,
                          style: GoogleFonts.inter(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _LanguageGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<LocaleProvider>();

    return SettingsGroup(
      title: l10n.language,
      icon: Icons.translate_rounded,
      footnote:
          'English and Hindi are fully translated. Further Indian languages '
          'will appear here as their translations are completed - the app does '
          'not offer a language it cannot render.',
      children: [
        SettingsRow(
          icon: Icons.language_rounded,
          label: 'App language',
          sublabel: provider.currentLanguageName,
          showDivider: false,
          onTap: () => _pick(context, provider),
        ),
      ],
    );
  }

  void _pick(BuildContext context, LocaleProvider provider) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Choose language',
                  style: GoogleFonts.inter(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            for (final locale in LocaleProvider.locales)
              ListTile(
                title: Text(
                  LocaleProvider.supportedLocales[locale.languageCode]!,
                  style: GoogleFonts.inter(fontSize: 15),
                ),
                trailing: provider.locale == locale
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.govBlue)
                    : null,
                onTap: () {
                  provider.setLocale(locale);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _SyncGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final outbox = context.watch<OutboxProvider>();

    return SettingsGroup(
      title: 'Offline queue',
      icon: Icons.sync_rounded,
      footnote: outbox.hasRejected
          ? 'Rejected items were refused by the server and will not be retried. '
              'Re-record them if they are still needed.'
          : outbox.hasPending
              ? 'Queued work is stored on this device and replays automatically. '
                  'The server deduplicates replays, so nothing is double-counted.'
              : null,
      children: [
        SettingsRow(
          icon: outbox.hasPending
              ? Icons.sync_problem_rounded
              : Icons.cloud_done_rounded,
          iconColor: outbox.hasPending
              ? AppColors.saffronDark
              : AppColors.indiaGreen,
          label: outbox.hasPending
              ? '${outbox.pendingCount} item(s) waiting'
              : 'Everything synced',
          sublabel: outbox.online ? 'Device is online' : 'Device is offline',
          showDivider: outbox.hasPending,
          trailing: outbox.hasPending && outbox.online
              ? FilledButton.tonal(
                  onPressed: outbox.flushing ? null : outbox.flush,
                  child: outbox.flushing
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Sync now'),
                )
              : null,
        ),
        for (var i = 0; i < outbox.ops.length; i++)
          SettingsRow(
            icon: Icons.pending_rounded,
            iconColor: AppColors.textTertiary,
            label: outbox.ops[i].label,
            sublabel: outbox.ops[i].lastError,
            showDivider:
                i < outbox.ops.length - 1 || outbox.hasRejected,
            trailing: IconButton(
              tooltip: 'Discard',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              onPressed: () => outbox.discard(outbox.ops[i].clientUuid),
            ),
          ),
        // Refused by the server and never retried. Shown rather than dropped:
        // an officer must not watch the pending count reach zero and assume
        // their submission landed.
        for (var i = 0; i < outbox.rejected.length; i++)
          SettingsRow(
            icon: Icons.report_problem_rounded,
            iconColor: AppColors.error,
            label: '${outbox.rejected[i].label} — not accepted',
            sublabel: outbox.rejected[i].lastError ??
                'The server refused this submission.',
            showDivider: i < outbox.rejected.length - 1,
            trailing: i == outbox.rejected.length - 1
                ? TextButton(
                    onPressed: outbox.acknowledgeRejected,
                    child: const Text('Dismiss'),
                  )
                : null,
          ),
      ],
    );
  }
}

class _ServerGroup extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerStatusProvider>();
    final status = server.status;

    return SettingsGroup(
      title: 'Server',
      icon: Icons.dns_rounded,
      footnote:
          'The endpoint is fixed at build time, so a device pointed at the '
          'wrong host is visible here rather than silently wrong.',
      children: [
        SettingsRow(
          icon: server.reachable
              ? Icons.check_circle_outline_rounded
              : Icons.error_outline_rounded,
          iconColor:
              server.reachable ? AppColors.indiaGreen : AppColors.error,
          label: server.reachable ? 'Online' : 'Unreachable',
          sublabel: AppConfig.isCleartext
              // Only reachable in debug builds, but nobody should demonstrate
              // over an unencrypted link without being told.
              ? '${AppConfig.apiBaseUrl}  ·  NOT ENCRYPTED'
              : AppConfig.apiBaseUrl,
          trailing: IconButton(
            tooltip: 'Re-check',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: server.refresh,
          ),
        ),
        if (status != null) ...[
          SettingsRow(
            icon: Icons.memory_rounded,
            label: 'Engine',
            sublabel: '${status.engineVersion} · rules ${status.shortRulesSha}',
          ),
          SettingsRow(
            icon: Icons.storage_rounded,
            label: 'Database',
            sublabel: status.db ?? '—',
          ),
          SettingsRow(
            icon: status.demoMode
                ? Icons.science_rounded
                : Icons.verified_user_rounded,
            iconColor:
                status.demoMode ? AppColors.saffronDark : AppColors.indiaGreen,
            label: status.demoMode ? 'Demo mode ON' : 'Demo mode OFF',
            sublabel: status.demoMode
                ? 'Serving seeded demonstration data'
                : 'Serving live records · env ${status.env}',
            showDivider: false,
          ),
        ],
      ],
    );
  }
}
