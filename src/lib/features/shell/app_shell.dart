import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/utils/responsive.dart';
import '../../providers/navigation_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/demo_mode_banner.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);
    final navProvider = context.watch<NavigationProvider>();
    final l10n = AppLocalizations.of(context);

    final destinations = [
      _NavDestination(l10n.dashboard, Icons.dashboard_rounded, '/dashboard'),
      _NavDestination(l10n.investigations, Icons.policy_rounded, '/investigations'),
      _NavDestination(l10n.projects, Icons.folder_special_rounded, '/projects'),
      _NavDestination(l10n.fieldVerification, Icons.camera_alt_rounded, '/field-verification'),
      _NavDestination(l10n.reports, Icons.bar_chart_rounded, '/reports'),
      _NavDestination(l10n.settings, Icons.settings_rounded, '/settings'),
    ];

    void onNavigate(int index) {
      navProvider.setIndex(index);
      context.go(destinations[index].route);
    }

    return Scaffold(
      body: Column(
        children: [
          const DemoModeBanner(),
          Expanded(
            child: Row(
              children: [
                if (!isMobile)
                  NavigationRail(
                    selectedIndex: navProvider.selectedIndex,
                    onDestinationSelected: onNavigate,
                    labelType: NavigationRailLabelType.all,
                    destinations: destinations.map((d) {
                      return NavigationRailDestination(
                        icon: Icon(d.icon),
                        label: Text(d.label),
                      );
                    }).toList(),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: navProvider.selectedIndex,
              onDestinationSelected: onNavigate,
              destinations: destinations.map((d) {
                return NavigationDestination(
                  icon: Icon(d.icon),
                  label: d.label,
                );
              }).toList(),
            )
          : null,
      floatingActionButton: isMobile ? null : FloatingActionButton(
        onPressed: () => context.push('/assistant'),
        tooltip: l10n.askSatya,
        child: const Icon(Icons.chat_bubble_rounded),
      ),
    );
  }
}

class _NavDestination {
  final String label;
  final IconData icon;
  final String route;
  
  _NavDestination(this.label, this.icon, this.route);
}
