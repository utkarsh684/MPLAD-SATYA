import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outbox_provider.dart';
import '../../providers/server_status_provider.dart';
import '../../widgets/settings_controls.dart';

/// Identity and authorisation — deliberately not preferences.
///
/// The question this screen answers is "who am I acting as, and what am I
/// permitted to do?". Anything an officer can *change* lives in Settings, so
/// the two never duplicate each other.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final outbox = context.watch<OutboxProvider>();
    final server = context.watch<ServerStatusProvider>();
    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          16,
          Responsive.horizontalPadding(context),
          40,
        ),
        children: [
          _IdentityHeader(user: user),
          const SizedBox(height: 24),

          SettingsGroup(
            title: 'Scope',
            icon: Icons.map_outlined,
            footnote:
                'The server restricts every list and decision to this scope. '
                'Widening it is not something the app can do.',
            children: [
              SettingsRow(
                icon: Icons.location_city_rounded,
                label: 'District',
                sublabel: user.districtName ?? 'Not assigned',
              ),
              SettingsRow(
                icon: Icons.account_balance_outlined,
                label: 'Department',
                sublabel: 'Ministry of Statistics & Programme Implementation',
                showDivider: false,
              ),
            ],
          ),

          _PermissionsGroup(user: user),

          SettingsGroup(
            title: 'Session',
            icon: Icons.verified_user_outlined,
            children: [
              SettingsRow(
                icon: outbox.hasPending
                    ? Icons.sync_problem_rounded
                    : Icons.cloud_done_rounded,
                iconColor: outbox.hasPending
                    ? AppColors.saffronDark
                    : AppColors.indiaGreen,
                label: 'Last synchronised',
                sublabel: _lastSync(outbox),
              ),
              SettingsRow(
                icon: server.reachable
                    ? Icons.link_rounded
                    : Icons.link_off_rounded,
                iconColor:
                    server.reachable ? AppColors.indiaGreen : AppColors.error,
                label: 'Connection',
                sublabel: server.reachable
                    ? 'Signed in and connected'
                    : 'Signed in, server unreachable',
              ),
              SettingsRow(
                icon: Icons.phone_android_rounded,
                label: 'Registered number',
                sublabel: user.phoneMasked,
                showDivider: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _lastSync(OutboxProvider outbox) {
    if (outbox.hasPending) {
      return '${outbox.pendingCount} item(s) still queued on this device';
    }
    final at = outbox.lastFlushAt;
    if (at == null) return 'Nothing has needed syncing this session';
    final mins = DateTime.now().difference(at).inMinutes;
    if (mins < 1) return 'Just now';
    if (mins < 60) return '$mins min ago';
    return DateFormat('dd MMM, HH:mm').format(at);
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.displayName,
            style: GoogleFonts.inter(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.saffron,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              user.roleLabel.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionsGroup extends StatelessWidget {
  const _PermissionsGroup({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    // Mirrors the server's RBAC. Shown so an officer knows in advance what
    // they may do, rather than discovering it through a 403.
    final permissions = <(String, bool)>[
      ('View works in scope', true),
      ('Upload site evidence', user.role != 'citizen'),
      ('Submit field verification', user.role != 'citizen'),
      ('Decide fund releases', user.canDecide),
      ('Recompute risk scores', user.canRecompute),
    ];

    return SettingsGroup(
      title: 'Permissions',
      icon: Icons.key_outlined,
      footnote:
          'Granted by role. The server enforces these independently — the app '
          'only hides what it knows you cannot do.',
      children: [
        for (var i = 0; i < permissions.length; i++)
          SettingsRow(
            icon: permissions[i].$2
                ? Icons.check_circle_outline
                : Icons.remove_circle_outline,
            iconColor: permissions[i].$2
                ? AppColors.indiaGreen
                : AppColors.textTertiary,
            label: permissions[i].$1,
            sublabel: permissions[i].$2 ? 'Allowed' : 'Not permitted',
            showDivider: i < permissions.length - 1,
          ),
      ],
    );
  }
}
