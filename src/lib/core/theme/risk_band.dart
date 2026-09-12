import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The server's three bands, and nothing else.
///
/// `weights.yaml` defines exactly: green 0-30, yellow 31-70, red 71-100. The
/// UI previously invented a fourth "Critical" tier at 81+, which meant a work
/// the engine called HIGH RISK could render as merely "High". Colour is now
/// driven by the band string the server sent, with the score only as a fallback
/// for the rare summary that carries a score but no band.
enum RiskBand {
  green('green', 'LOW RISK', AppColors.riskLow, Icons.check_circle_outline_rounded),
  yellow('yellow', 'REVIEW REQUIRED', AppColors.riskMedium, Icons.info_outline_rounded),
  red('red', 'HIGH RISK', AppColors.riskCritical, Icons.error_outline_rounded),
  unscored('unscored', 'NOT SCORED', AppColors.textTertiary, Icons.help_outline_rounded);

  const RiskBand(this.wire, this.defaultLabel, this.color, this.icon);

  final String wire;
  final String defaultLabel;
  final Color color;
  final IconData icon;

  static RiskBand fromWire(String? band, {int? score}) {
    switch (band) {
      case 'green':
        return RiskBand.green;
      case 'yellow':
        return RiskBand.yellow;
      case 'red':
        return RiskBand.red;
    }
    if (score == null) return RiskBand.unscored;
    if (score >= 71) return RiskBand.red;
    if (score >= 31) return RiskBand.yellow;
    return RiskBand.green;
  }

  Color background(bool isDark) => color.withValues(alpha: isDark ? 0.18 : 0.08);

  bool get isScored => this != RiskBand.unscored;
}
