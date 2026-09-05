import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../data/models/evidence_model.dart';

/// Expandable evidence card showing anomaly details.
class EvidenceCard extends StatefulWidget {
  final EvidenceModel evidence;
  final bool initiallyExpanded;

  const EvidenceCard({
    super.key,
    required this.evidence,
    this.initiallyExpanded = false,
  });

  @override
  State<EvidenceCard> createState() => _EvidenceCardState();
}

class _EvidenceCardState extends State<EvidenceCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  Color get _severityColor {
    switch (widget.evidence.severity) {
      case 'Critical':
        return AppColors.riskCritical;
      case 'High':
        return AppColors.riskHigh;
      case 'Medium':
        return AppColors.riskMedium;
      default:
        return AppColors.riskLow;
    }
  }

  IconData get _anomalyIcon {
    switch (widget.evidence.anomalyType) {
      case 'Cost Anomaly':
        return Icons.attach_money_rounded;
      case 'Geo-Duplicate':
        return Icons.location_on_rounded;
      case 'Execution Anomaly':
        return Icons.trending_down_rounded;
      case 'Image Similarity':
        return Icons.image_search_rounded;
      case 'Rule Violation':
        return Icons.gavel_rounded;
      case 'Timeline Anomaly':
        return Icons.schedule_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_anomalyIcon, color: _severityColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.evidence.anomalyType,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.evidence.supportingMetric,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Risk contribution badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _severityColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+${widget.evidence.riskContribution}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _severityColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: _buildExpandedContent(context),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
          const SizedBox(height: 8),

          // Explanation
          Text(
            widget.evidence.explanation,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 16),

          // Metrics row
          Row(
            children: [
              _buildMetricChip(
                context,
                'Severity',
                widget.evidence.severity,
                _severityColor,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                context,
                'Confidence',
                '${widget.evidence.confidence}%',
                AppColors.govBlue,
              ),
              const SizedBox(width: 8),
              _buildMetricChip(
                context,
                'Risk +',
                '${widget.evidence.riskContribution}',
                _severityColor,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Evidence source
          Row(
            children: [
              Icon(Icons.source_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.evidence.evidenceSource,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
            ],
          ),

          // Chart data visualization (simple bar comparison)
          if (widget.evidence.chartData != null &&
              widget.evidence.chartData!.containsKey('thisProject'))
            _buildCostComparison(context),

          if (widget.evidence.chartData != null &&
              widget.evidence.chartData!.containsKey('expenditurePercent'))
            _buildProgressComparison(context),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.8)),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCostComparison(BuildContext context) {
    final data = widget.evidence.chartData!;
    final thisProject = data['thisProject'] as double;
    final peerMedian = data['peerMedian'] as double;
    final maxVal = thisProject;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peer Cost Comparison',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          _buildBar('This Project', thisProject, maxVal, AppColors.riskCritical),
          const SizedBox(height: 6),
          _buildBar('Peer Median', peerMedian, maxVal, AppColors.indiaGreen),
        ],
      ),
    );
  }

  Widget _buildProgressComparison(BuildContext context) {
    final data = widget.evidence.chartData!;
    final expenditure = data['expenditurePercent'] as double;
    final progress = data['progressPercent'] as double;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expenditure vs Progress',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          _buildBar('Expenditure', expenditure, 100, AppColors.riskHigh),
          const SizedBox(height: 6),
          _buildBar('Physical Progress', progress, 100, AppColors.indiaGreen),
        ],
      ),
    );
  }

  Widget _buildBar(String label, double value, double max, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (value / max).clamp(0, 1),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '₹${value.toStringAsFixed(0)}L',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
