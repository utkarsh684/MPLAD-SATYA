import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/server_status_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/provenance.dart';

/// What SATYA is, and exactly where each number on screen comes from.
///
/// The provenance table here is the same classification the rest of the app
/// enforces in code, written out once so a judge or an officer can read the
/// whole picture in one place.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final server = context.watch<ServerStatusProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('About SATYA')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          24,
          Responsive.horizontalPadding(context),
          40,
        ),
        children: [
          Center(
            child: Column(
              children: [
                const AppLogo(size: 96, showText: false),
                const SizedBox(height: 14),
                const AppWordmark(size: 26),
                const SizedBox(height: 10),
                Text(
                  'Systematic Audit & Transparent\nYardstick Application',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Version 1.0.0  ·  SIH26102',
                    style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _Heading('Where the data comes from'),
          const SizedBox(height: 4),
          Text(
            'Every figure SATYA shows is traceable to one of these. Nothing is '
            'simulated without being labelled as simulated.',
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.5, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 14),

          const _SourceCard(
            name: 'Map & place search',
            detail: 'OpenStreetMap · Nominatim',
            state: SourceState.live,
            independent: true,
            note:
                'Live tiles and geocoding. Search is rate-limited to one '
                'request per second in line with the Nominatim usage policy.',
          ),
          const _SourceCard(
            name: 'Site evidence',
            detail: 'Field uploads',
            state: SourceState.local,
            independent: null,
            note:
                'Photographs captured by officers. EXIF and GPS are read on '
                'the server, faces are blurred before storage, and a '
                'perceptual hash detects the same photo reused elsewhere.',
          ),
          const _SourceCard(
            name: 'Cost benchmarks',
            detail: 'CPWD DSR 2024',
            state: SourceState.official,
            independent: true,
            note:
                'Published schedule of rates, transcribed with item-level '
                'references. A cost above benchmark is an anomaly to '
                'investigate, never proof of wrongdoing.',
          ),
          const _SourceCard(
            name: 'Satellite imagery',
            detail: 'ISRO Bhuvan',
            state: SourceState.fixture,
            independent: true,
            note:
                'Live when the server runs with SATELLITE_ADAPTER=bhuvan; a '
                'deterministic offline fixture otherwise. Every observation is '
                'stamped LIVE or FIXTURE on screen. Most MPLADS works are '
                'smaller than the sensor can resolve, so INCONCLUSIVE is the '
                'expected result and adds zero to the score.',
          ),
          const _SourceCard(
            name: 'Official works record',
            detail: 'eSAKSHI',
            state: SourceState.demoAdapter,
            independent: false,
            note:
                'MoSPI publishes no public API. The adapter currently reads '
                'the same database, so it exercises the comparison pipeline '
                'but does NOT independently corroborate anything. Only the '
                'adapter changes when official access is granted.',
          ),

          const SizedBox(height: 24),
          _Heading('This build'),
          const SizedBox(height: 10),
          _Kv('API endpoint', AppConfig.apiBaseUrl),
          if (server.status != null) ...[
            _Kv('Engine', server.status!.engineVersion),
            _Kv('Rulebook digest', server.status!.shortRulesSha),
            _Kv('Environment', server.status!.env),
            _Kv('Demo mode',
                server.demoMode ? 'ON — seeded data' : 'OFF — live records'),
          ] else
            _Kv('Server', 'Not reachable'),

          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.govBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The promise',
                    style: GoogleFonts.inter(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  'SATYA provides evidence, not verdicts. Approval remains an '
                  'administrative action by an authorised officer.',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, height: 1.6, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'Ministry of Statistics & Programme Implementation\n'
              'Smart India Hackathon 2026',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 11, height: 1.6, color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700),
      );
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({
    required this.name,
    required this.detail,
    required this.state,
    required this.independent,
    required this.note,
  });

  final String name;
  final String detail;
  final SourceState state;
  final bool? independent;
  final String note;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Text(name,
                    style: GoogleFonts.inter(
                        fontSize: 14, fontWeight: FontWeight.w700)),
              ),
              ProvenanceChip(state: state, detail: detail, dense: true),
            ],
          ),
          if (independent != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  independent! ? Icons.check_circle_outline_rounded : Icons.cancel_rounded,
                  size: 13,
                  color: independent!
                      ? AppColors.indiaGreen
                      : AppColors.saffronDark,
                ),
                const SizedBox(width: 5),
                Text(
                  independent!
                      ? 'Independent of SATYA'
                      : 'NOT independent of SATYA',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: independent!
                        ? AppColors.indiaGreen
                        : AppColors.saffronDark,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(note,
              style: GoogleFonts.inter(fontSize: 12, height: 1.55)),
        ],
      ),
    );
  }
}

class _Kv extends StatelessWidget {
  const _Kv(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: AppColors.textTertiary)),
          ),
          Expanded(
            child: SelectableText(value,
                style: GoogleFonts.robotoMono(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
