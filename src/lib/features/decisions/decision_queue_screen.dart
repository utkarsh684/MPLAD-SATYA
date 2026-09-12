import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/decision.dart';
import '../../data/repositories/decisions_repository.dart';
import '../../widgets/async_view.dart';

/// The officer's fund-release queue. The decision is an administrative act
/// recorded against the AI score, never taken by the AI.
class DecisionQueueScreen extends StatefulWidget {
  const DecisionQueueScreen({super.key});

  @override
  State<DecisionQueueScreen> createState() => _DecisionQueueScreenState();
}

class _DecisionQueueScreenState extends State<DecisionQueueScreen> {
  late Future<_QueueData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_QueueData> _load() async {
    final repo = context.read<DecisionsRepository>();
    final summary = repo.summary();
    final queue = repo.queue();
    return _QueueData(summary: await summary, releases: await queue);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fund release decisions')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: AsyncView<_QueueData>(
          future: _future,
          onRetry: _refresh,
          builder: (context, data) => ListView(
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            children: [
              _SummaryGrid(summary: data.summary),
              const SizedBox(height: 24),
              Text('PENDING (${data.releases.length})',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              const SizedBox(height: 12),
              if (data.releases.isEmpty)
                const EmptyState(
                  title: 'Queue is clear',
                  message: 'No fund releases are awaiting a decision.',
                  icon: Icons.task_alt_rounded,
                )
              else
                for (final release in data.releases)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReleaseCard(
                      release: release,
                      onDecided: _refresh,
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

class _QueueData {
  const _QueueData({required this.summary, required this.releases});
  final DecisionSummary summary;
  final List<FundRelease> releases;
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final DecisionSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: Responsive.isMobile(context) ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _MoneyTile(
            label: 'Total sanctioned',
            money: summary.totalSanctioned.display,
            color: AppColors.govBlue),
        _MoneyTile(
            label: 'Funds held',
            money: summary.fundsHeld.display,
            color: AppColors.riskCritical),
        _MoneyTile(
            label: 'Approved',
            money: summary.approvedForRelease.display,
            color: AppColors.indiaGreen),
        _MoneyTile(
            label: 'Pending review',
            money: summary.pendingReview.display,
            color: AppColors.saffronDark),
      ],
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile(
      {required this.label, required this.money, required this.color});
  final String label;
  final String money;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(money,
              style: GoogleFonts.inter(
                  fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: color)),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.onDecided});
  final FundRelease release;
  final Future<void> Function() onDecided;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final band =
        RiskBand.fromWire(release.work.riskBand, score: release.work.riskScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(release.work.workCode,
                    style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.govBlue)),
              ),
              if (band.isScored)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: band.background(isDark),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(band.icon, size: 12, color: band.color),
                      const SizedBox(width: 4),
                      Text(
                          '${release.work.riskScore} · ${release.work.bandLabel ?? band.defaultLabel}',
                          style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: band.color)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(release.work.title,
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(release.label,
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textTertiary)),
                    Text(release.claimedAmount.display,
                        style: GoogleFonts.inter(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context
                    .push(AppRouter.workDetailPath(release.work.workCode)),
                child: const Text('View evidence'),
              ),
            ],
          ),
          if ((release.evidenceSummary ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(release.evidenceSummary!,
                  style: GoogleFonts.inter(fontSize: 12, height: 1.4)),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _openDecisionSheet(context),
            icon: const Icon(Icons.gavel_rounded, size: 18),
            label: const Text('Record decision'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
          ),
        ],
      ),
    );
  }

  void _openDecisionSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: DecisionSheet(release: release, onDecided: onDecided),
      ),
    );
  }
}

/// Captures the officer's action plus the justification the audit log needs.
class DecisionSheet extends StatefulWidget {
  const DecisionSheet(
      {super.key, required this.release, required this.onDecided});

  final FundRelease release;
  final Future<void> Function() onDecided;

  @override
  State<DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<DecisionSheet> {
  DecisionAction? _action;
  final _justification = TextEditingController();
  final _statutoryRef = TextEditingController();
  int _partialPct = 50;
  bool _submitting = false;

  @override
  void dispose() {
    _justification.dispose();
    _statutoryRef.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final action = _action;
    if (action == null) return;

    setState(() => _submitting = true);
    try {
      final decision = await context.read<DecisionsRepository>().decide(
            releaseId: widget.release.id,
            action: action,
            justification: _justification.text,
            statutoryRef: _statutoryRef.text,
            partialPct:
                action == DecisionAction.partialRelease ? _partialPct : null,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.indiaGreen,
          content: Text(
            decision.auditSeq == null
                ? 'Decision recorded.'
                : 'Decision recorded · audit entry #${decision.auditSeq}',
          ),
        ),
      );
      await widget.onDecided();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final band = RiskBand.fromWire(widget.release.work.riskBand,
        score: widget.release.work.riskScore);
    final isRed = band == RiskBand.red;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Record decision',
                style: GoogleFonts.inter(
                    fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${widget.release.work.workCode} · ${widget.release.claimedAmount.display}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textTertiary),
            ),
            if (isRed) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.riskCritical.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.riskCritical.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        size: 18, color: AppColors.riskCritical),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The engine recommends holding this release. Approving '
                        'it requires a completed field verification or ministry '
                        'authority — the server enforces this.',
                        style: GoogleFonts.inter(fontSize: 11, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            for (final action in DecisionAction.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ActionOption(
                  action: action,
                  selected: _action == action,
                  onTap: () => setState(() => _action = action),
                ),
              ),
            if (_action == DecisionAction.partialRelease) ...[
              const SizedBox(height: 12),
              Text('Release $_partialPct% of the claim',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Slider(
                value: _partialPct.toDouble(),
                min: 1,
                max: 99,
                divisions: 98,
                label: '$_partialPct%',
                onChanged: (v) => setState(() => _partialPct = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _justification,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Justification',
                hintText: 'Why this decision, in your own words',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _statutoryRef,
              decoration: const InputDecoration(
                labelText: 'Statutory reference (optional)',
                hintText: 'e.g. MPLADS Guidelines 2023, para 3.9',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _action == null || _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit decision'),
            ),
            const SizedBox(height: 10),
            Text(
              'Recorded against the current AI score and appended to the '
              'tamper-evident audit chain.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionOption extends StatelessWidget {
  const _ActionOption(
      {required this.action, required this.selected, required this.onTap});

  final DecisionAction action;
  final bool selected;
  final VoidCallback onTap;

  (Color, IconData) get _style => switch (action) {
        DecisionAction.approve =>
          (AppColors.indiaGreen, Icons.check_circle_outline_rounded),
        DecisionAction.hold => (AppColors.riskCritical, Icons.pan_tool_rounded),
        DecisionAction.partialRelease =>
          (AppColors.saffronDark, Icons.pie_chart_outline_rounded),
        DecisionAction.fieldReview =>
          (AppColors.govBlue, Icons.engineering_rounded),
        DecisionAction.reAudit =>
          (AppColors.textSecondary, Icons.fact_check_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _style;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(
            color: selected
                ? color
                : (isDark ? AppColors.darkBorder : AppColors.border),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(action.label,
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? color : null)),
            ),
            if (selected) Icon(Icons.check_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
