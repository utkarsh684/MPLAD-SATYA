import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../data/models/project_model.dart';
import 'package:intl/intl.dart';

/// Card widget for displaying a project in lists.
class ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final VoidCallback? onTap;

  const ProjectCard({
    super.key,
    required this.project,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final riskColor = AppColors.riskColor(project.riskScore);
    final currencyFormatter = NumberFormat.currency(symbol: '₹', decimalDigits: 1);

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
                    project.id,
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
                project.name,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),

              // Location & Category
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${project.village}, ${project.district}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.category_outlined, size: 14, color: theme.textTheme.bodySmall?.color),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      project.category,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Divider
              Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
              const SizedBox(height: 8),

              // Details row: Cost, Progress, Risk
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailCol(
                    context,
                    'Sanctioned',
                    '${currencyFormatter.format(project.sanctionedAmount)}L',
                  ),
                  _buildDetailCol(
                    context,
                    'Progress',
                    '${project.physicalProgress}%',
                  ),
                  _buildDetailCol(
                    context,
                    'Risk',
                    '${project.riskScore}/100',
                    color: riskColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailCol(BuildContext context, String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color ?? theme.textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color bgColor;
    Color textColor;
    switch (project.status) {
      case 'In Progress':
        bgColor = AppColors.govBlue.withValues(alpha: 0.12);
        textColor = AppColors.govBlue;
        break;
      case 'Completed':
        bgColor = AppColors.indiaGreen.withValues(alpha: 0.12);
        textColor = AppColors.indiaGreen;
        break;
      case 'Near Completion':
        bgColor = AppColors.saffron.withValues(alpha: 0.12);
        textColor = AppColors.saffronDark;
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
        project.status,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
