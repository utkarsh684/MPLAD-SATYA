import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/satellite.dart';
import '../../../data/models/work.dart';
import '../../../data/repositories/works_repository.dart';
import '../../../widgets/async_view.dart';

/// The official MoSPI record, side by side with ours.
///
/// eSAKSHI publishes no REST API, so the server's adapter currently serves the
/// same rows through an external-source interface. That is stated on screen
/// rather than implied — an officer must never believe a field was
/// independently corroborated when it was not.
class EsakshiPanel extends StatefulWidget {
  const EsakshiPanel({super.key, required this.work});
  final WorkDetail work;

  @override
  State<EsakshiPanel> createState() => _EsakshiPanelState();
}

class _EsakshiPanelState extends State<EsakshiPanel> {
  late Future<_EsakshiData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EsakshiData> _load() async {
    final repo = context.read<WorksRepository>();
    final record = repo.esakshiRecord(widget.work.workCode);
    final verification = repo.esakshiVerify(widget.work.workCode);
    return _EsakshiData(
        record: await record, verification: await verification);
  }

  @override
  Widget build(BuildContext context) {
    return AsyncView<_EsakshiData>(
      future: _future,
      onRetry: () => setState(() => _future = _load()),
      loading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      ),
      builder: (context, data) {
        if (!data.record.found) {
          return const EmptyState(
            title: 'No official record',
            message: 'This work has no matching eSAKSHI entry.',
            icon: Icons.no_accounts_outlined,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VerdictBanner(verification: data.verification),
            const SizedBox(height: 16),
            _Comparison(work: widget.work, record: data.record),
            const SizedBox(height: 16),
            _SourceNote(),
          ],
        );
      },
    );
  }
}

class _EsakshiData {
  const _EsakshiData({required this.record, required this.verification});
  final EsakshiRecord record;
  final EsakshiVerification verification;
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({required this.verification});
  final EsakshiVerification verification;

  @override
  Widget build(BuildContext context) {
    final ok = verification.matches;
    final color = ok ? AppColors.indiaGreen : AppColors.riskCritical;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ok ? Icons.verified_rounded : Icons.report_problem_rounded,
                  size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ok
                      ? 'Consistent with the official record'
                      : '${verification.discrepancies.length} discrepancy(ies) found',
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Check(label: 'Amount', ok: verification.amountMatch),
              _Check(label: 'Status', ok: verification.statusMatch),
              _Check(label: 'Agency', ok: verification.agencyMatch),
            ],
          ),
          if (verification.discrepancies.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final d in verification.discrepancies)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text(d,
                          style: GoogleFonts.inter(
                              fontSize: 12, height: 1.45)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.label, required this.ok});
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.indiaGreen : AppColors.riskCritical;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check : Icons.close, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.work, required this.record});
  final WorkDetail work;
  final EsakshiRecord record;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(flex: 4, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text('SATYA',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.govBlue)),
              ),
              Expanded(
                flex: 3,
                child: Text('eSAKSHI',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.saffronDark)),
              ),
            ],
          ),
          const Divider(height: 18),
          _Row(
            label: 'Sanctioned',
            ours: work.sanctionedAmount.display,
            theirs: record.sanctionedAmount.display,
          ),
          _Row(label: 'Status', ours: work.status, theirs: record.status),
          _Row(
            label: 'Progress',
            ours: '${work.physicalProgressPct}%',
            theirs: '${record.physicalProgressPct}%',
          ),
          _Row(
            label: 'Agency',
            ours: work.implementingAgency ?? '—',
            theirs: record.implementingAgency ?? '—',
          ),
          const Divider(height: 18),
          _Row(
              label: 'Released',
              ours: '—',
              theirs: record.totalReleased.display),
          _Row(
              label: 'Pending',
              ours: '—',
              theirs: record.totalPending.display),
          _Row(
              label: 'Instalments',
              ours: '—',
              theirs: '${record.installmentsCount}'),
          if ((record.esakshiRef ?? '').isNotEmpty) ...[
            const Divider(height: 18),
            Row(
              children: [
                Text('Reference',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textTertiary)),
                const Spacer(),
                SelectableText(record.esakshiRef!,
                    style: GoogleFonts.robotoMono(fontSize: 11)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.ours, required this.theirs});
  final String label;
  final String ours;
  final String theirs;

  @override
  Widget build(BuildContext context) {
    final differs = ours != theirs && ours != '—' && theirs != '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textTertiary)),
          ),
          Expanded(
            flex: 3,
            child: Text(ours,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: differs ? AppColors.riskCritical : null,
                )),
          ),
          Expanded(
            flex: 3,
            child: Text(theirs,
                textAlign: TextAlign.right,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: differs ? AppColors.riskCritical : null,
                )),
          ),
        ],
      ),
    );
  }
}

class _SourceNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.saffron.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.saffron.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.saffronDark),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'eSAKSHI publishes no public API. This comparison runs through an '
              'adapter that currently reads the same database, so it validates '
              'the pipeline, not an independent source. Only the adapter\'s '
              'fetch method changes when MoSPI grants access.',
              style: GoogleFonts.inter(fontSize: 11, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
