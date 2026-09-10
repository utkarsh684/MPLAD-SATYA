import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/risk_band.dart';
import '../../core/utils/responsive.dart';

/// Plain-language guidance for an officer who has never seen the app.
///
/// The single most damaging misreading of SATYA is treating a risk score as a
/// fraud probability, so that is the first thing this screen corrects.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & guidance')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          16,
          Responsive.horizontalPadding(context),
          40,
        ),
        children: [
          _Callout(),
          const SizedBox(height: 24),
          _Section(
            title: 'What the score means',
            children: [
              _BandRow(
                band: RiskBand.green,
                range: '0 – 30',
                meaning: 'Nothing unusual found. Normal processing.',
              ),
              _BandRow(
                band: RiskBand.yellow,
                range: '31 – 70',
                meaning: 'Something needs a second look before release.',
              ),
              _BandRow(
                band: RiskBand.red,
                range: '71 – 100',
                meaning: 'Hold and verify on site before releasing funds.',
              ),
              const SizedBox(height: 12),
              _Body(
                'The score is a priority ranking, not a probability. A work '
                'scoring 78 is not "78% likely to be fraud" — it means several '
                'checks disagreed with the record, and it should be looked at '
                'before a work scoring 20.',
              ),
            ],
          ),
          _Section(
            title: 'Why these thresholds?',
            children: [
              _Body(
                'They are expert-assigned starting points, published in the '
                'rulebook and tunable per district — not values learned from '
                'data, because no labelled fraud dataset exists to learn them '
                'from. SATYA states this rather than implying a precision it '
                'does not have.',
              ),
            ],
          ),
          _Section(
            title: 'Reading the reasons',
            children: [
              _Body(
                'Every point in the score is attributable. The reasons listed '
                'under a work add up to the score exactly — you can check the '
                'arithmetic yourself. Each reason names the evidence it came '
                'from, so you can go and look at that evidence.',
              ),
            ],
          ),
          _Section(
            title: 'What an anomaly is not',
            children: [
              _Body(
                'A cost above the CPWD benchmark, a nearby similar work, or a '
                'photograph resembling another submission are all reasons to '
                'ask a question. None of them is proof of wrongdoing. Terrain, '
                'material haulage, phased works and genuine repeat designs all '
                'produce the same signals.',
              ),
            ],
          ),
          _Section(
            title: 'When a source says nothing',
            children: [
              _Body(
                'Satellite imagery cannot resolve a ward drain or a water '
                'kiosk — the asset is smaller than the sensor can see. SATYA '
                'records that as INCONCLUSIVE, and it adds zero to the score. '
                'A sensor that cannot see something is not evidence that '
                'something is wrong.',
              ),
            ],
          ),
          _Section(
            title: 'Working offline',
            children: [
              _Body(
                'Photographs and verifications you record without signal are '
                'saved on the device and sent automatically when you are back '
                'in coverage. The counter beside your profile shows how many '
                'are still waiting. Nothing is lost, and nothing is counted '
                'twice if it sends more than once.',
              ),
            ],
          ),
          _Section(
            title: 'Who decides',
            children: [
              _Body(
                'You do. SATYA never approves, holds or rejects a fund '
                'release. It assembles evidence and recommends. The decision '
                'recorded against a release is yours, with your justification, '
                'and it is written to a tamper-evident log alongside the score '
                'that was on screen when you made it.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.govBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.govBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.balance_rounded,
                  size: 20, color: AppColors.govBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SATYA provides evidence, not verdicts',
                  style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Approval remains an administrative action by an authorised '
            'officer. Nothing in this application decides how public money '
            'moves.',
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        height: 1.65,
        color: Theme.of(context).textTheme.bodyMedium?.color,
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    required this.band,
    required this.range,
    required this.meaning,
  });

  final RiskBand band;
  final String range;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 74,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: BoxDecoration(
              color: band.background(isDark),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(band.icon, size: 12, color: band.color),
                const SizedBox(width: 4),
                Text(range,
                    style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: band.color)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(meaning,
                  style: GoogleFonts.inter(fontSize: 13, height: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
