import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/evidence.dart';
import '../../data/models/risk.dart';
import '../../data/models/work.dart';
import '../../data/repositories/works_repository.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_view.dart';
import '../../widgets/evidence_tile.dart';
import '../../widgets/risk_score_indicator.dart';
import '../../widgets/source_card_tile.dart';
import 'widgets/esakshi_panel.dart';
import 'widgets/satellite_panel.dart';

/// The screen that has to survive "is this a black box?".
///
/// The reason list is rendered exactly as the server ordered it, with its
/// points, and the sum is shown next to the gauge so the arithmetic is visible.
///
/// Laid out as tabs rather than one long scroll: an officer arriving from the
/// decision queue needs the score and its reasons immediately, and should not
/// have to scroll past four screens of evidence to reach the official record.
class WorkDetailScreen extends StatefulWidget {
  const WorkDetailScreen({super.key, required this.workCode});
  final String workCode;

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  late Future<_WorkBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_WorkBundle> _load() async {
    final repo = context.read<WorksRepository>();
    // Four parallel calls rather than four round trips in sequence.
    final work = repo.detail(widget.workCode);
    final risk = repo.risk(widget.workCode);
    final verification = repo.verification(widget.workCode);
    final evidence = repo.evidence(widget.workCode);

    return _WorkBundle(
      work: await work,
      risk: await risk,
      verification: await verification,
      evidence: await evidence,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _recompute() async {
    try {
      await context.read<WorksRepository>().recompute(widget.workCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risk recomputed from current evidence.')),
      );
      await _refresh();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRecompute =
        context.watch<AuthProvider>().user?.canRecompute ?? false;
    final pad = Responsive.horizontalPadding(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(widget.workCode,
            style: GoogleFonts.robotoMono(
                fontSize: 14, fontWeight: FontWeight.w600)),
        actions: [
          if (canRecompute)
            IconButton(
              tooltip: 'Recompute risk',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _recompute,
            ),
        ],
      ),
      body: AsyncView<_WorkBundle>(
        future: _future,
        onRetry: _refresh,
        builder: (context, data) => DefaultTabController(
          length: 5,
          child: NestedScrollView(
            // The identity block stays pinned while the tabs scroll under it,
            // so the officer never loses track of which work they are judging.
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(pad, 8, pad, 0),
                  child: _Header(work: data.work),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarHeader(
                  TabBar(
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      const Tab(text: 'Risk'),
                      Tab(text: 'Sources (${data.verification.sources.length})'),
                      Tab(text: 'Evidence (${data.evidence.length})'),
                      const Tab(text: 'Official'),
                      const Tab(text: 'Satellite'),
                    ],
                  ),
                  Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _TabScroll(
                  padding: pad,
                  onRefresh: _refresh,
                  children: [
                    _ScoreBlock(risk: data.risk),
                    const SizedBox(height: 24),
                    _ReasonsSection(risk: data.risk),
                    const SizedBox(height: 24),
                    _DecisionBoundary(risk: data.risk),
                    const SizedBox(height: 24),
                    _ProvenanceFooter(risk: data.risk),
                  ],
                ),
                _TabScroll(
                  padding: pad,
                  onRefresh: _refresh,
                  children: [_SourcesSection(verification: data.verification)],
                ),
                _TabScroll(
                  padding: pad,
                  onRefresh: _refresh,
                  children: [_EvidenceSection(evidence: data.evidence)],
                ),
                _TabScroll(
                  padding: pad,
                  onRefresh: _refresh,
                  children: [EsakshiPanel(work: data.work)],
                ),
                _TabScroll(
                  padding: pad,
                  onRefresh: _refresh,
                  children: [SatellitePanel(workCode: widget.workCode)],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared tab body: consistent padding, pull-to-refresh on every tab.
class _TabScroll extends StatelessWidget {
  const _TabScroll({
    required this.padding,
    required this.children,
    required this.onRefresh,
  });

  final double padding;
  final List<Widget> children;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: EdgeInsets.fromLTRB(padding, 20, padding, 48),
        children: children,
      ),
    );
  }
}

class _TabBarHeader extends SliverPersistentHeaderDelegate {
  _TabBarHeader(this.tabBar, this.background);

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: background,
      elevation: overlapsContent ? 2 : 0,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarHeader old) =>
      old.tabBar != tabBar || old.background != background;
}

class _WorkBundle {
  const _WorkBundle({
    required this.work,
    required this.risk,
    required this.verification,
    required this.evidence,
  });

  final WorkDetail work;
  final RiskAssessment risk;
  final Verification verification;
  final List<Evidence> evidence;
}

class _Header extends StatelessWidget {
  const _Header({required this.work});
  final WorkDetail work;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFormat = DateFormat('dd MMM yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(work.title,
            style: GoogleFonts.inter(
                fontSize: 22, fontWeight: FontWeight.w700, height: 1.3)),
        const SizedBox(height: 8),
        if ((work.description ?? '').isNotEmpty)
          Text(work.description!,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      size: 16, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      work.locationLabel.isEmpty ? '—' : work.locationLabel,
                      style: GoogleFonts.inter(fontSize: 13),
                    ),
                  ),
                  Text(work.category,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
              const Divider(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 14,
                children: [
                  _Field(
                      label: 'Sanctioned',
                      value: work.sanctionedAmount.display),
                  _Field(
                      label: 'Progress',
                      value: '${work.physicalProgressPct}%'),
                  _Field(label: 'Quantity', value: work.sanctionedQtyLabel),
                  _Field(
                      label: 'Agency',
                      value: work.implementingAgency ?? '—'),
                  _Field(
                    label: 'Sanctioned on',
                    value: work.sanctionDate == null
                        ? '—'
                        : dateFormat.format(work.sanctionDate!),
                  ),
                  _Field(
                    label: 'Due',
                    value: work.expectedCompletionDate == null
                        ? '—'
                        : dateFormat.format(work.expectedCompletionDate!),
                  ),
                  if ((work.esakshiRef ?? '').isNotEmpty)
                    _Field(label: 'eSAKSHI ref', value: work.esakshiRef!),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color)),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final band = RiskBand.fromWire(risk.band, score: risk.score);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        RiskScoreIndicator(
          score: risk.score,
          band: band,
          size: 150,
          label: risk.bandLabel,
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: band.background(isDark),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: band.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text(
                risk.actionLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: band.color,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              // Server-owned text. A client build cannot drop this line.
              Text(
                risk.disclaimer,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              risk.consistencyPct == null
                  ? Icons.help_outline_rounded
                  : Icons.fact_check_rounded,
              size: 16,
              color: risk.consistencyPct == null
                  ? AppColors.textTertiary
                  : AppColors.govBlue,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                // Null is not zero. 0% would say every source contradicted the
                // record; null says no source could check it at all.
                risk.consistencyPct == null
                    ? 'Evidence consistency: not yet assessed'
                    : 'Evidence consistency ${risk.consistencyPct}%',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: risk.consistencyPct == null
                        ? AppColors.textTertiary
                        : AppColors.govBlue),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReasonsSection extends StatelessWidget {
  const _ReasonsSection({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    if (risk.reasons.isEmpty) {
      return const EmptyState(
        title: 'No risk signals fired',
        message: 'The engine found nothing to flag on this work.',
        icon: Icons.verified_rounded,
      );
    }

    final total = risk.reasonPointsTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('WHY?',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            Text('$total points',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Each reason carries the points it contributed. They add up to the '
          'score exactly - you can check the arithmetic.',
          style: GoogleFonts.inter(
              fontSize: 11, height: 1.45, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 12),
        for (final reason in risk.reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ReasonCard(reason: reason),
          ),
        // The arithmetic, shown. Reason points are apportioned server-side so
        // this equals the gauge exactly.
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${risk.reasons.map((r) => '+${r.points}').join('  ')}  =  $total',
            style: GoogleFonts.robotoMono(
                fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _ReasonCard extends StatefulWidget {
  const _ReasonCard({required this.reason});
  final RiskReason reason;

  @override
  State<_ReasonCard> createState() => _ReasonCardState();
}

class _ReasonCardState extends State<_ReasonCard> {
  bool _expanded = true;

  Color get _severityColor => switch (widget.reason.severity.toUpperCase()) {
        'CRITICAL' => AppColors.riskCritical,
        'HIGH' => AppColors.riskHigh,
        'MEDIUM' => AppColors.riskMedium,
        _ => AppColors.riskLow,
      };

  IconData get _icon => switch (widget.reason.category) {
        'rule' => Icons.gavel_rounded,
        'anomaly' => Icons.query_stats_rounded,
        'fraud' => Icons.fingerprint_rounded,
        'field' => Icons.straighten_rounded,
        'inefficiency' => Icons.schedule_rounded,
        _ => Icons.warning_amber_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded
              ? _severityColor.withValues(alpha: 0.4)
              : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(
                          alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon, color: _severityColor, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.reason.title,
                            style: GoogleFonts.inter(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.reason.category} · ${widget.reason.severity}',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(
                          alpha: isDark ? 0.18 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('+${widget.reason.points}',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _severityColor)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        color: theme.textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 16),
                  Text(widget.reason.explanation,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.55)),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.source_rounded,
                          size: 14, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.reason.provenance,
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // The stable machine code, so an officer can quote the exact
                  // rule in a file note.
                  Text(widget.reason.code,
                      style: GoogleFonts.robotoMono(
                          fontSize: 10, color: AppColors.textTertiary)),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
          ),
        ],
      ),
    );
  }
}

/// Draws the line the whole product depends on.
///
/// Above it, what SATYA computed. Below it, who actually decides. A judge
/// asking "so the AI approves the money?" should be able to read the answer
/// off the screen without anyone explaining it.
class _DecisionBoundary extends StatelessWidget {
  const _DecisionBoundary({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canDecide = context.watch<AuthProvider>().user?.canDecide ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SATYA ASSESSMENT',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.textTertiary)),
          const SizedBox(height: 6),
          Text('${risk.score} / 100  ·  ${risk.bandLabel}',
              style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text('Recommendation: ${risk.actionLabel}',
              style: GoogleFonts.inter(fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.textTertiary)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('NOT A DECISION',
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textTertiary)),
              ),
              const Expanded(child: Divider(color: AppColors.textTertiary)),
            ],
          ),
          const SizedBox(height: 14),
          Text('AUTHORISED OFFICER DECISION',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: AppColors.govBlue)),
          const SizedBox(height: 6),
          Text(
            canDecide
                ? 'Approve, hold or send for verification from the Decisions '
                    'queue. Your justification is recorded alongside this score '
                    'in the tamper-evident audit log.'
                : 'A district officer or ministry administrator records the '
                    'decision. SATYA never approves or rejects a release.',
            style: GoogleFonts.inter(fontSize: 12, height: 1.55),
          ),
          if (canDecide) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/decisions'),
              icon: const Icon(Icons.gavel_rounded, size: 18),
              label: const Text('Open decisions queue'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({required this.verification});
  final Verification verification;

  @override
  Widget build(BuildContext context) {
    if (verification.sources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('EVIDENCE SOURCES',
                style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            Text(
              verification.consistencyPct == null
                  ? 'Not assessed'
                  : '${verification.consistencyPct}% consistent',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: verification.consistencyPct == null
                    ? AppColors.textTertiary
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final source in verification.sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SourceCardTile(source: source),
          ),
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({required this.evidence});
  final List<Evidence> evidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SITE EVIDENCE (${evidence.length})',
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 12),
        if (evidence.isEmpty)
          const EmptyState(
            title: 'No evidence uploaded',
            message: 'Photos captured during field verification appear here.',
            icon: Icons.photo_camera_back_rounded,
          )
        else
          SizedBox(
            height: 200,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: evidence.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  EvidenceTile(evidence: evidence[i]),
            ),
          ),
      ],
    );
  }
}

/// Reproducibility, stated on the screen: a score computed today can be
/// re-explained in a year because the exact rulebook digest is recorded.
class _ProvenanceFooter extends StatelessWidget {
  const _ProvenanceFooter({required this.risk});
  final RiskAssessment risk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final format = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_rounded,
                  size: 14, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Text('How this score was produced',
                  style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Engine ${risk.engineVersion}\n'
            'Rulebook ${risk.rulesSha256}\n'
            '${risk.computedAt == null ? '' : 'Computed ${format.format(risk.computedAt!)}'}',
            style: GoogleFonts.robotoMono(
              fontSize: 10,
              height: 1.6,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }
}
