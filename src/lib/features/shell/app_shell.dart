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

  /// Exactly five destinations, whoever is signed in.
  ///
  /// This used to vary with role: a citizen saw four, a field officer five and
  /// a district officer six. Six is past the Material maximum, so the labels
  /// crushed together, and a bar that changes length between accounts is
  /// impossible to build muscle memory against.
  ///
  /// Settings is deliberately absent - it lives in the top-right profile menu,
  /// and having it in both places wasted an operational slot on something
  /// nobody opens mid-task. The freed slot goes to the map, which was
  /// previously reachable only through an icon buried in the works app bar.
  ///
  /// Slot three is the one that changes: it is whatever that role actually
  /// does all day. Everything still hidden here remains enforced server-side.
  List<_NavDestination> _destinationsFor(AppUser? user, AppLocalizations l10n) {
    final _NavDestination roleSlot;
    if (user?.canDecide ?? false) {
      roleSlot = _NavDestination('Decisions', Icons.gavel_rounded, '/decisions');
    } else if (user != null && user.role != 'citizen') {
      roleSlot = _NavDestination(
          l10n.fieldVerification, Icons.camera_alt_rounded, '/field');
    } else {
      // A citizen has neither queue; alerts are their equivalent entry point.
      roleSlot =
          _NavDestination('Alerts', Icons.notifications_rounded, '/alerts');
    }

    return [
      _NavDestination(l10n.dashboard, Icons.dashboard_rounded, '/dashboard'),
      _NavDestination(l10n.projects, Icons.folder_special_rounded, '/works'),
      roleSlot,
      _NavDestination('Map', Icons.map_rounded, '/map'),
      _NavDestination(l10n.reports, Icons.bar_chart_rounded, '/reports'),
    ];
  }
}

class _NavDestination {
  const _NavDestination(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
