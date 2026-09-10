import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/outbox_provider.dart';

/// Reads the real outbox depth. Tapping it forces a flush.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final outbox = context.watch<OutboxProvider>();
    final pending = outbox.pendingCount;
    final hasPending = pending > 0;
    final color = !outbox.online
        ? AppColors.textSecondary
        : hasPending
            ? AppColors.saffronDark
            : AppColors.indiaGreen;

    return Tooltip(
      message: hasPending
          ? 'Queued on this device. Replays are deduplicated by the server.'
          : 'Everything on this device has reached the server.',
      child: InkWell(
        onTap: hasPending && outbox.online ? outbox.flush : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (outbox.flushing)
                SizedBox(
                  height: 12,
                  width: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color),
                )
              else
                Icon(
                  hasPending
                      ? Icons.sync_problem_rounded
                      : Icons.cloud_done_rounded,
                  size: 14,
                  color: color,
                ),
              const SizedBox(width: 8),
              Text(
                hasPending ? '$pending pending' : 'Synced',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
