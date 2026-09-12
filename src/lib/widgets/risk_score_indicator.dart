import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/risk_band.dart';

/// The score gauge. Colour comes from the server's band, never from a
/// client-side threshold guess.
class RiskScoreIndicator extends StatelessWidget {
  const RiskScoreIndicator({
    super.key,
    required this.score,
    required this.band,
    this.size = 140,
    this.label,
  });

  final int score;
  final RiskBand band;
  final double size;
  final String? label;

  /// Stroke width of the ring, as a fraction of [size].
  static const _strokeFraction = 0.085;

  /// Widest column that stays clear of the ring.
  ///
  /// The inner circle is [size] less the stroke on both sides; the widest
  /// box that fits inside a circle is its diameter over root two. Deriving it
  /// rather than picking a number keeps it correct when [size] changes.
  double get _innerWidth =>
      (size - 2 * size * _strokeFraction) / math.sqrt2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: score / 100),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => CustomPaint(
              size: Size(size, size),
              painter: _GaugePainter(
                progress: value,
                color: band.color,
                trackColor: band.color.withValues(alpha: 0.14),
                strokeWidth: size * _strokeFraction,
              ),
            ),
          ),
          // Everything printed inside the ring has to fit a circle, not a
          // box. The label sits below the centre, where the chord is far
          // narrower than the inner diameter: at size 150 the inner circle is
          // about 124px across but only about 94px is available at the
          // label's height, and "REVIEW REQUIRED" wanted 114. It ran out over
          // the stroke on both sides.
          //
          // Constraining to the widest column that stays inside the circle,
          // and scaling down as a backstop, makes that true at any size and
          // for any band label - a longer one shrinks instead of escaping.
          SizedBox(
            width: _innerWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(band.icon, size: size * 0.13, color: band.color),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$score',
                    maxLines: 1,
                    style: GoogleFonts.inter(
                      fontSize: size * 0.3,
                      fontWeight: FontWeight.w800,
                      color: band.color,
                      height: 1,
                    ),
                  ),
                ),
                Text(
                  '/100',
                  style: GoogleFonts.inter(
                    fontSize: size * 0.09,
                    color: AppColors.textTertiary,
                  ),
                ),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label!,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: GoogleFonts.inter(
                        fontSize: size * 0.062,
                        fontWeight: FontWeight.w700,
                        color: band.color,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    const start = -math.pi / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, start, math.pi * 2, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, start, math.pi * 2 * progress.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.progress != progress || old.color != color;
}
