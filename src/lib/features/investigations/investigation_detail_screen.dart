import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../data/models/investigation_model.dart';
import '../../data/mock/mock_investigations.dart';
import '../../widgets/risk_score_indicator.dart';
import '../../widgets/confidence_score_indicator.dart';
import '../../widgets/evidence_card.dart';
import '../../widgets/officer_decision.dart';
import '../../widgets/audit_trail.dart';

class InvestigationDetailScreen extends StatelessWidget {
  final String investigationId;

  const InvestigationDetailScreen({
    super.key,
    required this.investigationId,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final investigation = MockInvestigations.all.firstWhere(
      (i) => i.id == investigationId,
      orElse: () => MockInvestigations.hero,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(investigation.project.id),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project Overview
            Text(
              l10n.projectOverview,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodySmall?.color),
            ),
            const SizedBox(height: 8),
            Text(
              investigation.project.name,
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _buildProjectDetails(context, investigation),
            const SizedBox(height: 32),
            
            // Scores
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                RiskScoreIndicator(
                  score: investigation.riskScore,
                  size: 140,
                  label: l10n.riskScore.toUpperCase(),
                ),
                ConfidenceScoreIndicator(
                  score: investigation.confidenceScore,
                  size: 140,
                  label: l10n.confidence.toUpperCase(),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            // Evidence Cards
            Text(
              l10n.whyFlagged.toUpperCase(),
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 1),
            ),
            const SizedBox(height: 16),
            ...investigation.evidence.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: EvidenceCard(evidence: e, initiallyExpanded: true),
            )),
            
            const SizedBox(height: 24),
            
            // Officer Decision
            OfficerDecision(
              onDecisionMade: () {},
            ),
            
            const SizedBox(height: 24),
            
            // Audit Trail
            AuditTrail(entries: investigation.auditTrail),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetails(BuildContext context, InvestigationModel investigation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 1);
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: theme.textTheme.bodySmall?.color),
              const SizedBox(width: 8),
              Text(
                '${investigation.project.village}, ${investigation.project.district}, ${investigation.project.state}',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(context, 'Sanctioned', '${currencyFormat.format(investigation.project.sanctionedAmount)}L'),
              _buildDetailItem(context, 'Expenditure', '${currencyFormat.format(investigation.project.expenditure)}L'),
              _buildDetailItem(context, 'Progress', '${investigation.project.physicalProgress}%'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDetailItem(context, 'Start Date', dateFormat.format(investigation.project.startDate)),
              _buildDetailItem(context, 'Exp. Completion', dateFormat.format(investigation.project.expectedCompletion)),
              _buildDetailItem(context, 'Status', investigation.project.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: theme.textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
