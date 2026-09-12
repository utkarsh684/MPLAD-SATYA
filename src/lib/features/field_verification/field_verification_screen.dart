import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/dashboard.dart';
import '../../data/repositories/field_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/async_view.dart';
import '../../widgets/sync_status_indicator.dart';
import 'verify_work_screen.dart';

/// The officer's real assignment queue, ordered by the server: highest risk
/// first, then soonest due. Distances come from PostGIS against the officer's
/// actual position — nothing here is assumed.
class FieldVerificationScreen extends StatefulWidget {
  const FieldVerificationScreen({super.key});

  @override
  State<FieldVerificationScreen> createState() =>
      _FieldVerificationScreenState();
}

class _FieldVerificationScreenState extends State<FieldVerificationScreen> {
  Future<List<Assignment>>? _future;
  Position? _position;
  bool _locating = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _position = await LocationService.instance.current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _future = _load();
    });
  }

  Future<List<Assignment>> _load() => context.read<FieldRepository>().myVerifications(
        lat: _position?.latitude,
        lon: _position?.longitude,
        limit: 50,
      );

  Future<void> _refresh() async {
    _position = await LocationService.instance.current();
    if (!mounted) return;
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fieldVerification),
        actions: const [SyncStatusIndicator(), SizedBox(width: 12)],
      ),
      body: _locating
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: AsyncView<List<Assignment>>(
                future: _future,
                onRetry: _refresh,
                isEmpty: (list) => list.isEmpty,
                emptyTitle: 'No assignments',
                emptyMessage:
                    'Work assigned to you for field verification appears here.',
                emptyIcon: Icons.assignment_turned_in_rounded,
                builder: (context, assignments) => ListView(
                  padding:
                      EdgeInsets.all(Responsive.horizontalPadding(context)),
                  children: [
                    if (_position == null) const _NoLocationBanner(),
                    for (final a in assignments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AssignmentCard(
                          assignment: a,
                          position: _position,
                          onDone: _refresh,
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

class _NoLocationBanner extends StatelessWidget {
  const _NoLocationBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.saffron.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.saffron.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded,
              size: 18, color: AppColors.saffronDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Location unavailable. Distances and on-site checks are disabled '
              'until location permission is granted.',
              style: GoogleFonts.inter(fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.assignment,
    required this.position,
    required this.onDone,
  });

  final Assignment assignment;
  final Position? position;
  final Future<void> Function() onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final work = assignment.work;
    final band = RiskBand.fromWire(work.riskBand, score: work.riskScore);
    final dateFormat = DateFormat('dd MMM');

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => VerifyWorkScreen(assignment: assignment),
          ),
        );
        await onDone();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: assignment.isOverdue
                ? AppColors.error.withValues(alpha: 0.5)
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(band.icon, size: 16, color: band.color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(work.workCode,
                      style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.govBlue)),
                ),
                if (assignment.dueAt != null)
                  Text(
                    assignment.isOverdue
                        ? 'OVERDUE'
                        : 'Due ${dateFormat.format(assignment.dueAt!)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: assignment.isOverdue
                          ? AppColors.error
                          : AppColors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(work.title,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: theme.textTheme.bodySmall?.color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    work.locationLabel.isEmpty ? '—' : work.locationLabel,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color),
                  ),
                ),
                if (work.distanceLabel != null)
                  Row(
                    children: [
                      const Icon(Icons.near_me_rounded,
                          size: 14, color: AppColors.govBlue),
                      const SizedBox(width: 4),
                      Text(work.distanceLabel!,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.govBlue)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (work.isScored)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: band.background(isDark),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                        'Risk ${work.riskScore} · ${work.bandLabel ?? band.defaultLabel}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: band.color)),
                  ),
                const Spacer(),
                Text(assignment.status.replaceAll('_', ' '),
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textTertiary)),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
