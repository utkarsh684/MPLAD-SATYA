import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

/// MPLAD SATYA logo widget — magnifying glass over a map/grid concept.
/// Reusable and replaceable with a final asset later.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final bool light; // use light colors (for dark backgrounds)

  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.light = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: light
                ? AppColors.white.withValues(alpha: 0.12)
                : AppColors.govBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(size * 0.25),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Grid/map dots representing infrastructure
              Positioned(
                top: size * 0.2,
                left: size * 0.2,
                child: _dot(size * 0.06, AppColors.indiaGreen.withValues(alpha: 0.6)),
              ),
              Positioned(
                top: size * 0.3,
                right: size * 0.25,
                child: _dot(size * 0.05, AppColors.saffron.withValues(alpha: 0.6)),
              ),
              Positioned(
                bottom: size * 0.25,
                left: size * 0.3,
                child: _dot(size * 0.05, AppColors.riskMedium.withValues(alpha: 0.5)),
              ),
              Positioned(
                bottom: size * 0.3,
                right: size * 0.2,
                child: _dot(size * 0.04, AppColors.riskCritical.withValues(alpha: 0.5)),
              ),
              // Magnifying glass
              Icon(
                Icons.search_rounded,
                size: size * 0.5,
                color: light ? AppColors.white : AppColors.govBlue,
              ),
            ],
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.15),
          Text(
            'MPLAD',
            style: GoogleFonts.inter(
              fontSize: size * 0.22,
              fontWeight: FontWeight.w700,
              color: light ? AppColors.white : AppColors.navy,
              letterSpacing: 2,
              height: 1.1,
            ),
          ),
          Text(
            'SATYA',
            style: GoogleFonts.inter(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w800,
              color: light ? AppColors.saffron : AppColors.govBlue,
              letterSpacing: 3,
              height: 1.2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _dot(double dotSize, Color color) {
    return Container(
      width: dotSize,
      height: dotSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
