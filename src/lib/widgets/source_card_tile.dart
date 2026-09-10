import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../data/models/risk.dart';

/// One of the four evidence sources.
///
/// An `inconclusive` satellite reading is rendered as neutral information, not
/// as a risk signal — sub-resolution targets genuinely cannot be confirmed from
/// orbit, and colouring that red would be an over-claim.
class SourceCardTile extends StatelessWidget {
  const SourceCardTile({super.key, required this.source});
  final SourceCard source;

  (Color, IconData) get _statusStyle => switch (source.status) {
        'match' => (AppColors.indiaGreen, Icons.check_circle_outline),
        'mismatch' => (AppColors.riskCritical, Icons.error_outline),
        'available' => (AppColors.govBlue, Icons.description_outlined),
        'inconclusive' => (AppColors.textSecondary, Icons.help_outline),
        _ => (AppColors.textTertiary, Icons.cloud_off_outlined),
      };

  IconData get _sourceIcon => switch (source.source) {
        'official_record' => Icons.account_balance_outlined,
        'satellite' => Icons.satellite_alt_outlined,
        'citizen' => Icons.groups_outlined,
        'field' => Icons.engineering_outlined,
        _ => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final (color, statusIcon) = _statusStyle;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_sourceIcon, size: 18, color: AppColors.govBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(source.sourceLabel,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: color),
                    const SizedBox(width: 4),
                    Text(source.statusLabel,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(source.headline,
              style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
          if (source.observedValue != null || source.confidence != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                if (source.observedValue != null)
                  _Metric(
                    label: 'Observed',
                    value:
                        '${_trim(source.observedValue!)}${source.observedUnit ?? ''}',
                  ),
                if (source.expectedValue != null)
                  _Metric(
                    label: 'Expected',
                    value:
                        '${_trim(source.expectedValue!)}${source.observedUnit ?? ''}',
                  ),
                if (source.confidence != null)
                  _Metric(
                    label: 'Confidence',
                    value: '${(source.confidence! * 100).round()}%',
                  ),
                if (source.reportCount > 0)
                  _Metric(label: 'Reports', value: '${source.reportCount}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textTertiary)),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
