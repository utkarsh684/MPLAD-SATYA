import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../data/models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/outbox_provider.dart';
import '../providers/theme_provider.dart';

/// Top-right identity control.
///
/// Deliberately NOT in the bottom navigation. The bottom bar answers "what do
/// I need to investigate?" and every slot in it is operational; who I am and
/// how the app is configured is a different question and belongs out of the
/// working path.
class ProfileMenuButton extends StatelessWidget {
  const ProfileMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final pending = context.watch<OutboxProvider>().pendingCount;

    return Semantics(
      button: true,
      label: user == null
          ? 'Account menu'
          : 'Account menu for ${user.displayName}, ${user.roleLabel}',
      child: Tooltip(
        message: 'Account and settings',
        child: InkWell(
          onTap: () => showProfileMenu(context),
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _Avatar(user: user, size: 32),
                    // Unsynced work is operationally urgent, so it surfaces on
                    // the avatar rather than only inside the menu.
                    if (pending > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.saffronDark,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).appBarTheme.backgroundColor ??
                                  AppColors.white,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 2),
                const Icon(Icons.expand_more_rounded, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the account sheet. Kept a top-level function so any screen's app bar
/// can raise it without importing the button.
Future<void> showProfileMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ProfileSheet(),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user, this.size = 40});

  final AppUser? user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.govBlue,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials(user?.displayName),
        style: GoogleFonts.inter(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final theme = context.watch<ThemeProvider>();

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Identity header, not a settings row: who is signed in, and with
            // what authority.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Row(
                children: [
                  _Avatar(user: user, size: 48),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? '—',
                          style: GoogleFonts.inter(
                              fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [user?.roleLabel, user?.districtName]
                              .where((e) => (e ?? '').isNotEmpty)
                              .join(' · '),
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            _MenuRow(
              icon: Icons.badge_outlined,
              label: 'Profile',
              sublabel: 'Identity, scope and permissions',
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),

            // Theme lives here as a direct control rather than a navigation
            // hop: it is the one preference people change often.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  const Icon(Icons.palette_outlined,
                      size: 20, color: AppColors.govBlue),
                  const SizedBox(width: 14),
                  Text('Appearance',
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(54, 0, 20, 12),
              child: SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                      GoogleFonts.inter(fontSize: 12)),
                ),
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('Auto'),
                    icon: Icon(Icons.brightness_auto_outlined, size: 16),
                  ),
                ],
                selected: {theme.themeMode},
                onSelectionChanged: (s) => theme.setThemeMode(s.first),
              ),
            ),
            const Divider(height: 1),

            _MenuRow(
              icon: Icons.settings_outlined,
              label: 'Settings',
              sublabel: 'Language, sync, privacy',
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            _MenuRow(
              icon: Icons.help_outline_rounded,
              label: 'Help & guidance',
              sublabel: 'How to read a risk score',
              onTap: () {
                Navigator.pop(context);
                context.push('/help');
              },
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: 'About SATYA',
              sublabel: 'Version and data sources',
              onTap: () {
                Navigator.pop(context);
                context.push('/about');
              },
            ),
            const Divider(height: 1),
            _MenuRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              color: AppColors.error,
              onTap: () async {
                Navigator.pop(context);
                await _confirmSignOut(context, auth);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmSignOut(
      BuildContext context, AuthProvider auth) async {
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.sublabel,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        // 56 dp minimum touch target, consistent with the rest of the app.
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.govBlue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: GoogleFonts.inter(
                            fontSize: 11.5, color: AppColors.textTertiary)),
                  ],
                ],
              ),
            ),
            if (color == null)
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}
