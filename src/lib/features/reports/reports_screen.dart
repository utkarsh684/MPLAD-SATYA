import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/analytics.dart';
import '../../data/repositories/analytics_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/async_view.dart';

/// Live analytics, computed by the server on request.
///
/// The old version listed pre-canned "reports" with dead export buttons. There
/// is no report-generation endpoint in the backend, so this screen shows the
/// aggregates that do exist and offers the audit-chain check instead of a
/// button that does nothing.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<_ReportsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReportsData> _load() async {
    final repo = context.read<AnalyticsRepository>();
    final overview = repo.overview();
    final districts = repo.districtSummary();
    final rules = repo.ruleFrequency();
    return _ReportsData(
      overview: await overview,
      districts: await districts,
      rules: await rules,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _verifyChain() async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Walking the audit chain…')),
    );
    try {
      final result = await context.read<AnalyticsRepository>().verifyAuditChain();
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      showDialog<void>(
        context: context,
        builder: (context) => _ChainResultDialog(result: result),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            tooltip: 'Rulebook',
            icon: const Icon(Icons.rule_folder_outlined),
            onPressed: () => context.push('/rulebook'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView<_ReportsData>(
          future: _future,
          onRetry: _refresh,
          builder: (context, data) => ListView(
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            children: [
              _Section(
                title: 'Portfolio',
                child: Column(
                  children: [
                    _StatRow(
                        label: 'Works tracked',
                        value: '${data.overview.totalWorks}'),
                    _StatRow(
                        label: 'Assessed',
                        value: '${data.overview.assessedWorks}'),
                    _StatRow(
                        label: 'Total sanctioned',
                        value: data.overview.totalSanctioned.display),
                    _StatRow(
                        label: 'Average risk score',
                        value:
                            '${data.overview.averageRiskScore.toStringAsFixed(1)}'
                            '/100  (of ${data.overview.assessedWorks} assessed)'),
                    _StatRow(
                        label: 'Evidence items',
                        value: '${data.overview.totalEvidenceItems}'),
                    _StatRow(
                        label: 'Decisions recorded',
                        value: '${data.overview.totalDecisions}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (data.districts.isNotEmpty) ...[
                _Section(
                  title: 'By district',
                  child: Column(
                    children: [
                      for (final d in data.districts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(d.district,
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600)),
                                    Text(
                                        '${d.works} works · '
                                        '${d.assessedWorks} assessed · '
                                        '${d.totalSanctioned.display}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                            fontSize: 11,
                                            color: AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                              // Null average means nothing in this district has
                              // been assessed. Rendering 0.0 here would colour
                              // it green and rank it as the safest district.
                              if (!d.hasAssessments)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.textTertiary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('not assessed',
                                      style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textTertiary)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: RiskBand.fromWire(null,
                                            score: d.avgRiskScore!.round())
                                        .color
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  // The denominator travels with the number:
                                  // a bare "6.8" beside work scores shown as
                                  // "78/100" reads as a different scale.
                                  child: Text(
                                    '${d.avgRiskScore!.toStringAsFixed(1)}/100',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: RiskBand.fromWire(null,
                                              score: d.avgRiskScore!.round())
                                          .color,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (data.rules.isNotEmpty) ...[
                _Section(
                  title: 'Which rules are firing',
                  subtitle:
                      'Across every current assessment. Rules that never fire '
                      'are as informative as the ones that do.',
                  child: Column(
                    children: [
                      for (final r in data.rules.take(12))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(r.code,
                                        style: GoogleFonts.robotoMono(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                    Text(r.category,
                                        style: GoogleFonts.inter(
                                            fontSize: 10,
                                            color: AppColors.textTertiary)),
                                  ],
                                ),
                              ),
                              Text('${r.fires}×',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 12),
                              // Fixed-width boxes burst as soon as the system
                              // font scale rises; the text has to be allowed
                              // to shrink instead of overflow.
                              SizedBox(
                                width: 62,
                                child: Text(
                                  'avg +${r.avgPoints.toStringAsFixed(1)}',
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textTertiary),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _Section(
                title: 'Integrity',
                subtitle:
                    'Every decision and evidence upload is appended to a '
                    'SHA-256 hash chain. Re-verify it here at any time.',
                child: OutlinedButton.icon(
                  onPressed: _verifyChain,
                  icon: const Icon(Icons.verified_user_outlined, size: 18),
                  label: const Text('Verify audit chain'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
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

class _ReportsData {
  const _ReportsData({
    required this.overview,
    required this.districts,
    required this.rules,
  });

  final AnalyticsOverview overview;
  final List<DistrictSummary> districts;
  final List<RuleFrequency> rules;
}

class _ChainResultDialog extends StatelessWidget {
  const _ChainResultDialog({required this.result});
  final AuditVerification result;

  @override
  Widget build(BuildContext context) {
    final ok = result.valid;
    return AlertDialog(
      icon: Icon(
        ok ? Icons.verified_rounded : Icons.gpp_bad_rounded,
        color: ok ? AppColors.indiaGreen : AppColors.error,
        size: 40,
      ),
      title: Text(ok ? 'Chain intact' : 'Chain broken'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ok
                ? '${result.checked} entries re-hashed and verified. '
                    'No record has been altered or removed.'
                : 'Verification failed at sequence ${result.brokenAtSeq}. '
                    '${result.problem ?? ''}',
            style: GoogleFonts.inter(fontSize: 13, height: 1.5),
          ),
          if (result.headHash != null) ...[
            const SizedBox(height: 14),
            Text('Head hash',
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textTertiary)),
            SelectableText(
              result.headHash!,
              style: GoogleFonts.robotoMono(fontSize: 10),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    height: 1.45,
                    color: AppColors.textTertiary)),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
