import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/dashboard.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../data/repositories/field_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/outbox_provider.dart';
import '../../widgets/async_view.dart';

/// Alerts derived from live server state.
///
/// The backend has no notifications table, so rather than invent a feed this
/// screen composes alerts out of facts it can actually verify: assignments
/// that are overdue or due today, works the engine currently bands red, and
/// this device's own unsynced queue. Every row links to the real record.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<_Alert>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_Alert>> _load() async {
    final analytics = context.read<AnalyticsRepository>();
    final field = context.read<FieldRepository>();
    final user = context.read<AuthProvider>().user;
    final isFieldUser = user != null && user.role != 'citizen';

    final topRiskFuture = analytics.topRisk(limit: 20);
    final assignmentsFuture =
        isFieldUser ? field.myVerifications(limit: 50) : null;

    final topRisk = await topRiskFuture;
    final assignments = await assignmentsFuture;

    final alerts = <_Alert>[];

    for (final a in assignments ?? const <Assignment>[]) {
      if (a.isOverdue) {
        alerts.add(_Alert(
          severity: _Severity.critical,
          title: 'Verification overdue',
          body: '${a.work.title} was due ${_ago(a.dueAt!)}.',
          workCode: a.work.workCode,
          at: a.dueAt,
        ));
      } else if (a.isDueToday) {
        alerts.add(_Alert(
          severity: _Severity.warning,
          title: 'Verification due today',
          body: a.work.title,
          workCode: a.work.workCode,
          at: a.dueAt,
        ));
      }
    }

    for (final w in topRisk.where((w) => w.band == 'red')) {
      alerts.add(_Alert(
        severity: _Severity.critical,
        title: 'High risk · score ${w.score}',
        body: '${w.title} (${w.category})',
        workCode: w.workCode,
      ));
    }

    return alerts;
  }

  static String _ago(DateTime when) {
    final days = DateTime.now().difference(when).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final outbox = context.watch<OutboxProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView<List<_Alert>>(
          future: _future,
          onRetry: _refresh,
          isEmpty: (list) => list.isEmpty && !outbox.hasPending,
          emptyTitle: 'Nothing needs your attention',
          emptyMessage:
              'Overdue verifications and high-risk works will appear here.',
          emptyIcon: Icons.notifications_none_rounded,
          builder: (context, alerts) => ListView(
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            children: [
              if (outbox.hasPending) ...[
                _OutboxAlert(outbox: outbox),
                const SizedBox(height: 12),
              ],
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AlertTile(alert: alert),
                ),
              const SizedBox(height: 24),
              Text(
                'Alerts are computed from current server state each time this '
                'screen loads. There is no stored notification history.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

enum _Severity { critical, warning, info }

class _Alert {
  const _Alert({
    required this.severity,
    required this.title,
    required this.body,
    this.workCode,
    this.at,
  });

  final _Severity severity;
  final String title;
  final String body;
  final String? workCode;
  final DateTime? at;
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});
  final _Alert alert;

  (Color, IconData) get _style => switch (alert.severity) {
        _Severity.critical => (AppColors.riskCritical, Icons.error_rounded),
        _Severity.warning => (AppColors.riskHigh, Icons.warning_rounded),
        _Severity.info => (AppColors.govBlue, Icons.info_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (color, icon) = _style;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: alert.workCode == null
          ? null
          : () => context.push(AppRouter.workDetailPath(alert.workCode!)),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(alert.title,
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      if (alert.at != null)
                        Text(DateFormat('dd MMM').format(alert.at!),
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textTertiary)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(alert.body,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
                  if (alert.workCode != null) ...[
                    const SizedBox(height: 6),
                    Text(alert.workCode!,
                        style: GoogleFonts.robotoMono(
                            fontSize: 10, color: AppColors.govBlue)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutboxAlert extends StatelessWidget {
  const _OutboxAlert({required this.outbox});
  final OutboxProvider outbox;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.saffron.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.saffron.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded,
              color: AppColors.saffronDark, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${outbox.pendingCount} item(s) waiting to sync',
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  outbox.ops.map((o) => o.label).toSet().join(', '),
                  style: GoogleFonts.inter(fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: outbox.online && !outbox.flushing ? outbox.flush : null,
            child: const Text('Sync now'),
          ),
        ],
      ),
    );
  }
}
