import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/satellite.dart';
import '../../../data/repositories/works_repository.dart';
import '../../../widgets/async_view.dart';
import '../../../widgets/provenance.dart';

/// ISRO Bhuvan observation panel.
///
/// The point of this panel is calibrated honesty. Cartosat resolves about
/// 2.5 m, so a ward drain or a water kiosk is genuinely invisible from orbit
/// and the engine records `inconclusive` contributing zero points. Rather than
/// hide that behind a confidence bar, the panel shows the detectability
/// arithmetic and names which adapter produced the reading.
class SatellitePanel extends StatefulWidget {
  const SatellitePanel({super.key, required this.workCode});
  final String workCode;

  @override
  State<SatellitePanel> createState() => _SatellitePanelState();
}

class _SatellitePanelState extends State<SatellitePanel> {
  late Future<List<SatelliteResult>> _future;
  bool _observing = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<WorksRepository>().satelliteHistory(widget.workCode);
  }

  Future<void> _observe() async {
    setState(() => _observing = true);
    try {
      final result =
          await context.read<WorksRepository>().observeSatellite(widget.workCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              result.isLive ? AppColors.indiaGreen : AppColors.textSecondary,
          content: Text('${result.sourceLabel}: ${result.statusLabel}'),
        ),
      );
      setState(() => _future = context
          .read<WorksRepository>()
          .satelliteHistory(widget.workCode));
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _observing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: _observing ? null : _observe,
          icon: _observing
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.satellite_alt_rounded, size: 18),
          label: Text(_observing
              ? 'Contacting Bhuvan…'
              : 'Run satellite observation'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
        ),
        const SizedBox(height: 8),
        Text(
          'Fetches imagery through the server\'s configured adapter and '
          'recomputes risk with the result.',
          style: GoogleFonts.inter(
              fontSize: 11, height: 1.4, color: AppColors.textTertiary),
        ),
        const SizedBox(height: 16),
        AsyncView<List<SatelliteResult>>(
          future: _future,
          loading: const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          isEmpty: (list) => list.isEmpty,
          emptyTitle: 'No observations yet',
          emptyMessage:
              'Run one to compare built-up change against reported progress.',
          emptyIcon: Icons.satellite_alt_outlined,
          builder: (context, results) => Column(
            children: [
              for (final r in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ObservationCard(result: r),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ObservationCard extends StatelessWidget {
  const _ObservationCard({required this.result});
  final SatelliteResult result;

  (Color, IconData) get _style => switch (result.status) {
        'match' => (AppColors.indiaGreen, Icons.check_circle_outline),
        'mismatch' => (AppColors.riskCritical, Icons.error_outline),
        'inconclusive' => (AppColors.textSecondary, Icons.visibility_off_outlined),
        _ => (AppColors.textTertiary, Icons.cloud_off_outlined),
      };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (color, icon) = _style;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(result.statusLabel,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color)),
              ),
              // Never ambiguous about whether this was a live satellite call.
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (result.isLive
                          ? AppColors.indiaGreen
                          : AppColors.textTertiary)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  result.isLive ? 'LIVE' : 'FIXTURE',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: result.isLive
                        ? AppColors.indiaGreen
                        : AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Plain language first. The index, the ratio and the method are
          // behind one tap for anyone who wants to check the working.
          Text(result.plainVerdict,
              style: GoogleFonts.inter(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (result.detectabilityLabel != null)
            Row(
              children: [
                Text('Detectability  ',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textTertiary)),
                Text(result.detectabilityLabel!,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: result.detectabilityRatio! >= 1.0
                            ? AppColors.indiaGreen
                            : AppColors.saffronDark)),
              ],
            ),
          const SizedBox(height: 10),
          ProvenanceBlock(
            state: result.isLive
                ? (result.status == 'unavailable'
                    ? SourceState.unavailable
                    : SourceState.live)
                : SourceState.fixture,
            source: result.isLive ? 'ISRO Bhuvan' : 'Offline fixture',
            isIndependent: result.isLive ? true : false,
            observedAt: result.captureDate,
            limitation: result.limitation,
          ),

          TechnicalDetails(
            children: [
              const SizedBox(height: 4),
              Text(result.reason,
                  style: GoogleFonts.inter(fontSize: 12, height: 1.55)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _Metric(
                      label: 'Reported confidence',
                      value: '${(result.confidence * 100).round()}%'),
                  _Metric(
                      label: 'Sensor resolution',
                      value: '${result.resolutionM} m/px'),
                  _Metric(label: 'Method', value: result.method),
                  _Metric(
                    label: 'Temporal comparison',
                    value: result.isTemporalComparison ? 'Yes' : 'No',
                  ),
                  if (result.brightnessIndex != null)
                    _Metric(
                      label: 'Brightness contrast',
                      value: result.brightnessIndex!.toStringAsFixed(3),
                    ),
                  if (result.hasDetectability) ...[
                    _Metric(
                        label: 'Target size',
                        value: '${result.targetDimensionM!.toStringAsFixed(1)} m'),
                    _Metric(
                        label: 'Min detectable',
                        value: '${result.minDetectableM!.toStringAsFixed(1)} m'),
                  ],
                  if (result.provider != null)
                    _Metric(label: 'Provider', value: result.provider!),
                ],
              ),
              if (result.brightnessIndex != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Brightness contrast is (R-G)/(R+G) over a rendered visual '
                  'tile. It is NOT NDBI: Bhuvan\'s public WMS carries no SWIR '
                  'or NIR band, so a true built-up index cannot be computed '
                  'from it. Treat it as a weak corroborating hint.',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.textTertiary),
                ),
              ],
              if (result.isInconclusive) ...[
                const SizedBox(height: 10),
                Text(
                  'An inconclusive reading adds ZERO points to the risk score. '
                  'A sensor that cannot see something is not evidence that '
                  'something is wrong.',
                  style: GoogleFonts.inter(
                      fontSize: 10.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: AppColors.textTertiary)),
        Text(value,
            style:
                GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
