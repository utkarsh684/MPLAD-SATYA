import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/investigations/investigation_list_screen.dart';
import '../../features/investigations/investigation_detail_screen.dart';
import '../../features/projects/project_list_screen.dart';
import '../../features/projects/project_map_screen.dart';
import '../../features/field_verification/field_verification_screen.dart';
import '../../features/field_verification/ar_measurement_screen.dart';
import '../../features/reports/reports_screen.dart';
import '../../features/notifications/notification_screen.dart';
import '../../features/assistant/assistant_screen.dart';
import '../../features/settings/settings_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class AppRouter {
  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
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
            path: '/investigations',
            builder: (context, state) => const InvestigationListScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => InvestigationDetailScreen(
                  investigationId: state.pathParameters['id']!,
                ),
              ),
            ]
          ),
          GoRoute(
            path: '/projects',
            builder: (context, state) => const ProjectListScreen(),
          ),
          GoRoute(
            path: '/map',
            builder: (context, state) => const ProjectMapScreen(),
          ),
          GoRoute(
            path: '/field-verification',
            builder: (context, state) => const FieldVerificationScreen(),
          ),
          GoRoute(
            path: '/ar-measurement',
            builder: (context, state) => const ARMeasurementScreen(),
          ),
          GoRoute(
            path: '/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) => const NotificationScreen(),
          ),
          GoRoute(
            path: '/assistant',
            builder: (context, state) => const AssistantScreen(),
          ),
        ],
      ),
    ],
  );
}
