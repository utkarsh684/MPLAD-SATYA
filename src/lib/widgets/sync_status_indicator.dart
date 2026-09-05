import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../l10n/app_localizations.dart';

class SyncStatusIndicator extends StatelessWidget {
  final int pendingItems;

  const SyncStatusIndicator({
    super.key,
    required this.pendingItems,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final bool hasPending = pendingItems > 0;
    final color = hasPending ? AppColors.saffronDark : AppColors.indiaGreen;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasPending ? Icons.sync_problem_rounded : Icons.cloud_done_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(
            hasPending ? '$pendingItems ${l10n.itemsWaitingSync}' : l10n.syncQueue,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
