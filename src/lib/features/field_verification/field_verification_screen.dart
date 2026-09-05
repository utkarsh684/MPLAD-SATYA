import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../data/mock/mock_investigations.dart';
import '../../widgets/sync_status_indicator.dart';

class FieldVerificationScreen extends StatelessWidget {
  const FieldVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final investigation = MockInvestigations.hero; // use hero project for demo

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.fieldVerification),
        actions: const [
          SyncStatusIndicator(pendingItems: 3),
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Project info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investigation.project.name,
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 8),
                      Text(
                        '${investigation.project.village}, ${investigation.project.district}',
                        style: GoogleFonts.inter(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.gps_fixed, size: 16, color: AppColors.indiaGreen),
                      const SizedBox(width: 8),
                      Text(
                        'GPS Verified: You are within 10m of site.',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.indiaGreen, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Actions
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.camera_alt_rounded),
              label: Text(l10n.capturePhoto),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => context.push('/ar-measurement'),
              icon: const Icon(Icons.view_in_ar_rounded),
              label: Text(l10n.recordMeasurement),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.note_add_rounded),
              label: Text(l10n.addNote),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            const SizedBox(height: 48),
            
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.indiaGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(l10n.submitVerification),
            ),
          ],
        ),
      ),
    );
  }
}
