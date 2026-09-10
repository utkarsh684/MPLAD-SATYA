import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/utils/responsive.dart';
import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/demo_mode_banner.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;

    final destinations = _destinationsFor(user, l10n);
    final location = GoRouterState.of(context).matchedLocation;
    var index = destinations.indexWhere((d) => location.startsWith(d.route));
    if (index < 0) index = 0;

    void onNavigate(int i) => context.go(destinations[i].route);

    return Scaffold(
      body: Column(
        children: [
          const DemoModeBanner(),
          Expanded(
            child: Row(
              children: [
                if (!isMobile)
                  NavigationRail(
                    selectedIndex: index,
                    onDestinationSelected: onNavigate,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: Icon(d.icon),
                          label: Text(d.label),
                        ),
                    ],
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: index,
              onDestinationSelected: onNavigate,
              destinations: [
                for (final d in destinations)
                  NavigationDestination(icon: Icon(d.icon), label: d.label),
              ],
            )
          : null,
    );
  }

  /// The nav mirrors the server's RBAC: a field officer has no decision queue,
  /// and a citizen has neither. Hiding what the caller cannot do keeps the app
  /// honest; the server still enforces every boundary.
  List<_NavDestination> _destinationsFor(AppUser? user, AppLocalizations l10n) {
    final items = <_NavDestination>[
      _NavDestination(l10n.dashboard, Icons.dashboard_rounded, '/dashboard'),
      _NavDestination(l10n.projects, Icons.folder_special_rounded, '/works'),
    ];

    if (user?.canDecide ?? false) {
      items.add(_NavDestination(
          'Decisions', Icons.gavel_rounded, '/decisions'));
    }
    if (user != null && user.role != 'citizen') {
      items.add(_NavDestination(
          l10n.fieldVerification, Icons.camera_alt_rounded, '/field'));
    }

    items.add(_NavDestination(l10n.reports, Icons.bar_chart_rounded, '/reports'));
    items.add(_NavDestination(l10n.settings, Icons.settings_rounded, '/settings'));
    return items;
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
