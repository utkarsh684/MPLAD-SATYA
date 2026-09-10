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
                strokeWidth: size * 0.085,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(band.icon, size: size * 0.13, color: band.color),
              const SizedBox(height: 2),
              Text(
                '$score',
                style: GoogleFonts.inter(
                  fontSize: size * 0.3,
                  fontWeight: FontWeight.w800,
                  color: band.color,
                  height: 1,
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
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: size * 0.073,
                    fontWeight: FontWeight.w700,
                    color: band.color,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
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
