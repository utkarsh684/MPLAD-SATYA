/// Static app identity only.
///
/// Everything that describes *data* — districts, categories, statuses, risk
/// thresholds — has been removed. Those are server-owned vocabularies: a
/// hardcoded district list goes stale the moment a district is added, and a
/// client-side risk threshold that disagrees with `weights.yaml` mislabels the
/// engine's own output. Categories and statuses now arrive with the records
/// themselves, and bands live in [RiskBand], mapped from what the server sent.
class AppConstants {
  AppConstants._();

  static const String appName = 'MPLAD SATYA';
  static const String appTagline = 'Evidence. Insight. Better Governance.';
  static const String appSubtitle = 'Evidence-Driven Risk Intelligence';
  static const String appVersion = '1.0.0';
  static const String sihId = 'SIH26102';
  static const String organization =
      'Ministry of Statistics & Programme Implementation';
}
