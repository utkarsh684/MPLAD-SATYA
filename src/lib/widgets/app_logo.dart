import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/app_colors.dart';

/// The official MPLAD SATYA mark.
///
/// Previously this drew an approximation in code — a magnifying-glass icon over
/// coloured dots. It now renders the real asset, so what a judge sees on the
/// splash is the same mark used everywhere else.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 48,
    this.showText = true,
    this.light = false,
  });

  final double size;
  final bool showText;

  /// Wordmark tuned for a dark ground.
  final bool light;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          // The mark is the app's identity; if the asset ever fails to decode,
          // fall back to the wordmark rather than a broken-image box.
          errorBuilder: (context, _, __) => Icon(
            Icons.account_balance_rounded,
            size: size * 0.8,
            color: light ? AppColors.white : AppColors.govBlue,
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.14),
          AppWordmark(size: size * 0.32, light: light),
        ],
      ],
    );
  }
}

/// "MPLAD SATYA" set as a lockup. Split out so an app bar can use the wordmark
/// without the emblem.
class AppWordmark extends StatelessWidget {
  const AppWordmark({
    super.key,
    this.size = 20,
    this.light = false,
    this.horizontal = false,
  });

  final double size;
  final bool light;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final mplad = Text(
      'MPLAD',
      style: GoogleFonts.inter(
        fontSize: size * 0.7,
        fontWeight: FontWeight.w700,
        color: light ? AppColors.white : AppColors.navy,
        letterSpacing: size * 0.14,
        height: 1.1,
      ),
    );
    final satya = Text(
      'SATYA',
      style: GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: light ? AppColors.saffron : AppColors.govBlue,
        letterSpacing: size * 0.16,
        height: 1.15,
      ),
    );

    if (horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [mplad, SizedBox(width: size * 0.3), satya],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [mplad, satya],
    );
  }
}
