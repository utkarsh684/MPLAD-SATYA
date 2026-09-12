import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../providers/outbox_provider.dart';
import '../providers/server_status_provider.dart';

/// A status strip that tells the truth about the running system.
///
/// It shows the demo flag only when the server actually reports `demo_mode`,
/// and it shows an offline strip when the device is genuinely offline. Pointed
/// at a production instance with a live connection, it renders nothing.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerStatusProvider>();
    final outbox = context.watch<OutboxProvider>();

    if (!outbox.online) {
      return _Strip(
        color: AppColors.textSecondary,
        icon: Icons.cloud_off_rounded,
        text: outbox.hasPending
            ? 'OFFLINE — ${outbox.pendingCount} item(s) queued, will sync automatically'
            : 'OFFLINE — showing last loaded data',
      );
    }

    if (!server.reachable) {
      return _Strip(
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
        text: 'Cannot reach the SATYA server',
      );
    }

    if (server.demoMode) {
      return const _Strip(
        color: AppColors.saffron,
        icon: Icons.science_rounded,
        text: 'DEMO MODE — server is running on seeded demonstration data',
      );
    }

    return const SizedBox.shrink();
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.color, required this.icon, required this.text});

  final Color color;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.92),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
