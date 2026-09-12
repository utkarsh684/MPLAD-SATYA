import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/decisions/decision_queue_screen.dart';
import '../../features/field_verification/field_verification_screen.dart';
import '../../features/field_verification/measurement_screen.dart';
import '../../features/help/about_screen.dart';
import '../../features/help/help_screen.dart';
import '../../features/notifications/alerts_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/rulebook/rulebook_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/works/work_detail_screen.dart';
import '../../features/works/work_list_screen.dart';
import '../../features/works/work_map_screen.dart';
import '../../providers/auth_provider.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  /// The router listens to [auth] so an expired session anywhere in the app
  /// bounces straight back to login instead of leaving a dead screen up.
  static GoRouter build(AuthProvider auth) => GoRouter(
        navigatorKey: _rootNavigatorKey,
        initialLocation: '/splash',
        refreshListenable: auth,
        redirect: (context, state) {
          final loc = state.matchedLocation;
          switch (auth.status) {
            case AuthStatus.restoring:
              // Hold on the splash until we know whether a session survived.
              return loc == '/splash' ? null : '/splash';
            case AuthStatus.signedOut:
            case AuthStatus.awaitingOtp:
              return loc == '/login' ? null : '/login';
            case AuthStatus.signedIn:
              return (loc == '/login' || loc == '/splash') ? '/dashboard' : null;
          }
        },
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => const LoginScreen(),
          ),
          ShellRoute(
            navigatorKey: _shellNavigatorKey,
            builder: (context, state, child) => AppShell(child: child),
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
              GoRoute(
                path: '/works',
                builder: (context, state) => const WorkListScreen(),
              ),
              GoRoute(
                path: '/decisions',
                builder: (context, state) => const DecisionQueueScreen(),
              ),
              GoRoute(
                path: '/field',
                builder: (context, state) => const FieldVerificationScreen(),
              ),
              GoRoute(
                path: '/reports',
                builder: (context, state) => const ReportsScreen(),
              ),
              // Inside the shell: both are bottom-bar destinations, so they
              // must keep the bar visible. Opening a tab full-screen strands
              // the officer with only the system back gesture to escape.
              GoRoute(
                path: '/map',
                builder: (context, state) => const WorkMapScreen(),
              ),
              GoRoute(
                path: '/alerts',
                builder: (context, state) => const AlertsScreen(),
              ),
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
          // Full-screen routes, pushed above the shell.
          GoRoute(
            path: '/works/:code/detail',
            builder: (context, state) => WorkDetailScreen(
              workCode: Uri.decodeComponent(state.pathParameters['code']!),
            ),
          ),
          GoRoute(
            path: '/rulebook',
            builder: (context, state) => const RulebookScreen(),
          ),
          // Identity and app configuration. Reached from the top-right profile
          // control, deliberately never from the operational bottom bar.
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/help',
            builder: (context, state) => const HelpScreen(),
          ),
          GoRoute(
            path: '/about',
            builder: (context, state) => const AboutScreen(),
          ),
          GoRoute(
            path: '/measure',
            builder: (context, state) {
              final extra = state.extra as MeasurementArgs?;
              return MeasurementScreen(args: extra);
            },
          ),
        ],
      );

  /// Work codes contain slashes (`MP/2026/1142`), so they must be encoded
  /// before going into a path segment.
  static String workDetailPath(String workCode) =>
      '/works/${Uri.encodeComponent(workCode)}/detail';
}
