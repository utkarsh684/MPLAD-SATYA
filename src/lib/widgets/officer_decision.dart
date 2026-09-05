import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class OfficerDecision extends StatefulWidget {
  final VoidCallback onDecisionMade;

  const OfficerDecision({
    super.key,
    required this.onDecisionMade,
  });

  @override
  State<OfficerDecision> createState() => _OfficerDecisionState();
}

class _OfficerDecisionState extends State<OfficerDecision> {
  String? _selectedDecision;

  void _handleDecision(String decision) {
    setState(() {
      _selectedDecision = decision;
    });
    
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDecision),
        content: Text('Are you sure you want to mark this investigation as "$decision"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onDecisionMade();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Decision recorded successfully.')),
              );
            },
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.gavel_rounded, color: AppColors.govBlue),
              const SizedBox(width: 12),
              Text(
                l10n.officerDecision,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.aiDisclaimer,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 20),
          _DecisionButton(
            title: l10n.verified,
            icon: Icons.check_circle_outline,
            color: AppColors.indiaGreen,
            isSelected: _selectedDecision == l10n.verified,
            onTap: () => _handleDecision(l10n.verified),
          ),
          const SizedBox(height: 10),
          _DecisionButton(
            title: l10n.needsFurtherInvestigation,
            icon: Icons.search_rounded,
            color: AppColors.saffronDark,
            isSelected: _selectedDecision == l10n.needsFurtherInvestigation,
            onTap: () => _handleDecision(l10n.needsFurtherInvestigation),
          ),
          const SizedBox(height: 10),
          _DecisionButton(
            title: l10n.falsePositive,
            icon: Icons.cancel_outlined,
            color: AppColors.textSecondary,
            isSelected: _selectedDecision == l10n.falsePositive,
            onTap: () => _handleDecision(l10n.falsePositive),
          ),
          const SizedBox(height: 10),
          _DecisionButton(
            title: l10n.escalate,
            icon: Icons.trending_up_rounded,
            color: AppColors.riskCritical,
            isSelected: _selectedDecision == l10n.escalate,
            onTap: () => _handleDecision(l10n.escalate),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DecisionButton({
    required this.title,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            border: Border.all(
              color: isSelected ? color : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? color : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
