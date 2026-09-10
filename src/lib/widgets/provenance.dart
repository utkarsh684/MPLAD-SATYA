import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// The single vocabulary the whole app uses to describe where a fact came from.
///
/// Centralised deliberately. When provenance logic is duplicated per screen it
/// drifts, and the first thing to drift is the distinction between a real
/// observation and a stand-in for one. Every label below is defined once here
/// and rendered by [ProvenanceChip] and [ProvenanceBlock].
enum SourceState {
  /// A real, current call to an external service succeeded.
  live('LIVE', AppColors.indiaGreen, Icons.sensors_rounded),

  /// Deterministic stand-in data. Never a real observation.
  fixture('FIXTURE', AppColors.saffronDark, Icons.science_outlined),

  /// Computed by SATYA from data we hold, e.g. our own uploads.
  local('LOCAL', AppColors.govBlue, Icons.storage_rounded),

  /// A published government reference, e.g. CPWD DSR.
  official('OFFICIAL', AppColors.govBlue, Icons.account_balance_rounded),

  /// An adapter shaped like an external source but not independent of us.
  demoAdapter('DEMO ADAPTER', AppColors.saffronDark, Icons.cable_rounded),

  /// The source ran but could not decide either way.
  inconclusive('INCONCLUSIVE', AppColors.textSecondary, Icons.help_outline),

  /// The source could not be reached, or returned nothing usable.
  unavailable('UNAVAILABLE', AppColors.textTertiary, Icons.cloud_off_rounded),

  /// The call failed outright.
  failed('FAILED', AppColors.error, Icons.error_outline_rounded),

  /// We genuinely do not know.
  unknown('UNKNOWN', AppColors.textTertiary, Icons.remove_rounded);

  const SourceState(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  /// Whether this state may be used to support a conclusion about the work.
  /// Everything else is context, not evidence.
  bool get isEvidential => this == live || this == local || this == official;
}

/// A compact source badge. Use wherever a value is shown that came from
/// somewhere a reader might otherwise assume was authoritative.
class ProvenanceChip extends StatelessWidget {
  const ProvenanceChip({
    super.key,
    required this.state,
    this.detail,
    this.dense = false,
  });

  final SourceState state;

  /// The specific source, e.g. "Bhuvan", "eSAKSHI", "CPWD DSR 2024".
  final String? detail;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = detail == null ? state.label : '${state.label} · $detail';

    return Semantics(
      label: 'Source: $text',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 7 : 9,
          vertical: dense ? 2 : 4,
        ),
        decoration: BoxDecoration(
          color: state.color.withValues(alpha: isDark ? 0.20 : 0.10),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: state.color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A filled dot plus an icon: never colour alone.
            Icon(state.icon, size: dense ? 10 : 12, color: state.color),
            SizedBox(width: dense ? 4 : 5),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: dense ? 9 : 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: state.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The full provenance disclosure, shown under any evidence a decision rests on.
///
/// Answers, in order: where did this come from, is it independent of us, when
/// was it observed, and what can it not tell you.
class ProvenanceBlock extends StatelessWidget {
  const ProvenanceBlock({
    super.key,
    required this.state,
    required this.source,
    this.isIndependent,
    this.observedAt,
    this.limitation,
    this.reference,
  });

  final SourceState state;

  /// Human name of the source, e.g. "ISRO Bhuvan".
  final String source;

  /// Null when independence is not a meaningful question for this source
  /// (our own uploads, for instance).
  final bool? isIndependent;

  final String? observedAt;

  /// What this source cannot establish. The most important line here.
  final String? limitation;

  /// A citable identifier, e.g. "Item 16.42".
  final String? reference;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('SOURCE',
                  style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textTertiary)),
              const Spacer(),
              ProvenanceChip(state: state, detail: source, dense: true),
            ],
          ),
          if (isIndependent != null) ...[
            const SizedBox(height: 8),
            _Line(
              label: 'Independent of SATYA',
              value: isIndependent! ? 'Yes' : 'No',
              emphasis: !isIndependent!,
            ),
          ],
          if (observedAt != null) ...[
            const SizedBox(height: 6),
            _Line(label: 'Observed', value: observedAt!),
          ],
          if (reference != null) ...[
            const SizedBox(height: 6),
            _Line(label: 'Reference', value: reference!, mono: true),
          ],
          if (limitation != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    limitation!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasis = false,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool emphasis;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 11, color: AppColors.textTertiary)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: mono
                ? GoogleFonts.robotoMono(fontSize: 11)
                : GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: emphasis ? AppColors.saffronDark : null,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Progressive disclosure: a plain-language summary with the technical detail
/// folded away behind one tap.
///
/// An officer should not have to parse a brightness index to learn that
/// satellite could not resolve the asset. The number stays available for
/// anyone who wants to check the working.
class TechnicalDetails extends StatefulWidget {
  const TechnicalDetails({
    super.key,
    required this.children,
    this.label = 'View technical details',
  });

  final List<Widget> children;
  final String label;

  @override
  State<TechnicalDetails> createState() => _TechnicalDetailsState();
}

class _TechnicalDetailsState extends State<TechnicalDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          label: widget.label,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.govBlue,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(Icons.expand_more_rounded,
                        size: 18, color: AppColors.govBlue),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.children,
          ),
          crossFadeState:
              _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 160),
        ),
      ],
    );
  }
}
