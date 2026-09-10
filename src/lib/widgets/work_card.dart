import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/risk_band.dart';
import '../data/models/work.dart';

/// List row for a work. Every value shown is a field the server sent —
/// money uses the server's own display string, never a client-side format.
class WorkCard extends StatelessWidget {
  const WorkCard({super.key, required this.work, this.onTap});

  final WorkSummary work;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final band = RiskBand.fromWire(work.riskBand, score: work.riskScore);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                  Expanded(
                    child: Text(
                      work.workCode,
                      style: GoogleFonts.robotoMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.govBlue,
                      ),
                    ),
                  ),
                  _StatusBadge(status: work.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                work.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
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
                  Icon(Icons.category_outlined,
                      size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      work.category,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color),
                    ),
                  ),
                ],
              ),
              if (work.distanceLabel != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined,
                        size: 14, color: AppColors.govBlue),
                    const SizedBox(width: 4),
                    Text(
                      work.distanceLabel!,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.govBlue),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: isDark ? AppColors.darkDivider : AppColors.divider),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Detail(
                        label: 'Sanctioned',
                        value: work.sanctionedAmount.display),
                  ),
                  Expanded(
                    child: work.isScored
                        ? _Detail(
                            label: 'Risk',
                            value: '${work.riskScore}/100',
                            color: band.color,
                          )
                        : _Detail(
                            label: 'Risk',
                            value: 'Not scored',
                            color: AppColors.textTertiary,
                          ),
                  ),
                  if (band.isScored)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: band.background(isDark),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Never colour-only: the icon carries the same
                          // information for colour-blind users.
                          Icon(band.icon, size: 12, color: band.color),
                          const SizedBox(width: 4),
                          Text(
                            work.bandLabel ?? band.defaultLabel,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: band.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: theme.textTheme.bodySmall?.color)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color ?? theme.textTheme.bodyLarge?.color)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    // Server status vocabulary, not display strings invented on the client.
    final (color, label) = switch (status) {
      'completed' => (AppColors.indiaGreen, 'Completed'),
      'in_progress' => (AppColors.govBlue, 'In Progress'),
      'sanctioned' => (AppColors.saffronDark, 'Sanctioned'),
      'recommended' => (AppColors.textSecondary, 'Recommended'),
      'proposed' => (AppColors.textSecondary, 'Proposed'),
      'held' => (AppColors.error, 'Held'),
      'cancelled' => (AppColors.textTertiary, 'Cancelled'),
      _ => (AppColors.textTertiary, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
