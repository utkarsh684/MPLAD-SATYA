import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../data/models/investigation_model.dart';

/// Card widget for displaying an investigation item in lists.
class InvestigationCard extends StatelessWidget {
  final InvestigationModel investigation;
  final VoidCallback? onTap;

  const InvestigationCard({
    super.key,
    required this.investigation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final riskColor = AppColors.riskColor(investigation.riskScore);

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
              color: isDark ? AppColors.darkBorder : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: ID + Status badge
              Row(
                children: [
                  Text(
                    investigation.project.id,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.govBlue,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(context),
                ],
              ),
              const SizedBox(height: 8),

              // Project name
              Text(
                investigation.project.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),

              // Location
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    '${investigation.project.village}, ${investigation.project.district}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.category_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Text(
                    investigation.project.category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Risk / Confidence / Exposure row
              Row(
                children: [
                  _buildScorePill('Risk', investigation.riskScore, riskColor),
                  const SizedBox(width: 8),
                  _buildScorePill('Confidence', investigation.confidenceScore, AppColors.govBlue),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: isDark ? 0.15 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      investigation.exposureLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: riskColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Primary signal
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.insights_rounded, size: 14, color: riskColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        investigation.primarySignalDescription,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.textTheme.bodyMedium?.color,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScorePill(String label, int score, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey),
        ),
        Text(
          '$score',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (investigation.status) {
      case 'Pending Verification':
        bgColor = AppColors.riskMedium.withValues(alpha: 0.12);
        textColor = AppColors.riskMedium;
        break;
      case 'Under Investigation':
        bgColor = AppColors.govBlue.withValues(alpha: 0.12);
        textColor = AppColors.govBlue;
        break;
      case 'Field Verification':
        bgColor = AppColors.saffron.withValues(alpha: 0.12);
        textColor = AppColors.saffronDark;
        break;
      case 'Verified':
        bgColor = AppColors.indiaGreen.withValues(alpha: 0.12);
        textColor = AppColors.indiaGreen;
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.12);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        investigation.status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
