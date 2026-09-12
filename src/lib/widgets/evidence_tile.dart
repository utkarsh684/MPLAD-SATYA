import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_colors.dart';
import '../data/models/evidence.dart';

/// A real uploaded photo, served from the backend's /media mount, with the
/// forensic metadata the server computed for it.
class EvidenceTile extends StatelessWidget {
  const EvidenceTile({super.key, required this.evidence});
  final Evidence evidence;

  Color get _trustColor {
    final t = evidence.gpsTrust;
    if (t == null) return AppColors.textTertiary;
    if (t >= 80) return AppColors.indiaGreen;
    if (t >= 50) return AppColors.riskMedium;
    return AppColors.riskCritical;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () => _showDetail(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 120,
              width: double.infinity,
              child: Image.network(
                evidence.absoluteUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (context, _, __) => Container(
                  color: AppColors.surfaceVariant,
                  child: const Icon(Icons.broken_image_rounded,
                      color: AppColors.textTertiary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gps_fixed_rounded, size: 12, color: _trustColor),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          evidence.gpsTrust == null
                              ? 'No GPS'
                              : 'GPS ${evidence.gpsTrust}/100',
                          style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _trustColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    evidence.capturedAt == null
                        ? evidence.source
                        : DateFormat('dd MMM, HH:mm')
                            .format(evidence.capturedAt!),
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                evidence.absoluteUrl,
                errorBuilder: (context, _, __) => const SizedBox(
                  height: 200,
                  child: Center(child: Icon(Icons.broken_image_rounded)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Evidence metadata',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _Row(label: 'Source', value: evidence.source),
            _Row(label: 'GPS trust', value: evidence.trustLabel),
            _Row(
              label: 'Captured',
              value: evidence.capturedAt == null
                  ? 'Not in EXIF'
                  : DateFormat('dd MMM yyyy, HH:mm')
                      .format(evidence.capturedAt!),
            ),
            _Row(
              label: 'Faces blurred',
              value: '${evidence.facesBlurred}',
              note: 'Blurred on ingest for DPDP compliance',
            ),
            if (evidence.width != null)
              _Row(
                  label: 'Dimensions',
                  value: '${evidence.width} × ${evidence.height}'),
            _Row(label: 'SHA-256', value: evidence.sha256, mono: true),
            if (evidence.phashHex != null)
              _Row(
                label: 'Perceptual hash',
                value: evidence.phashHex!,
                mono: true,
                note: 'Used to detect the same photo reused on another work',
              ),
            if (evidence.gpsFlags.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('GPS flags',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final flag in evidence.gpsFlags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.riskCritical.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(flag,
                          style: GoogleFonts.robotoMono(
                              fontSize: 11, color: AppColors.riskCritical)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.mono = false,
    this.note,
  });

  final String label;
  final String value;
  final bool mono;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: AppColors.textTertiary)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: mono
                ? GoogleFonts.robotoMono(fontSize: 11)
                : GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (note != null)
            Text(note!,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
