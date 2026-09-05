/// App-wide constants and configuration.
class AppConstants {
  AppConstants._();

  // ─── Risk Thresholds ───
  static const int riskCriticalMin = 81;
  static const int riskHighMin = 61;
  static const int riskMediumMin = 31;
  static const int riskLowMin = 0;

  // ─── App Info ───
  static const String appName = 'MPLAD SATYA';
  static const String appTagline = 'Evidence. Insight. Better Governance.';
  static const String appSubtitle = 'Evidence-Driven Risk Intelligence';
  static const String appVersion = '1.0.0';
  static const String sihId = 'SIH26102';
  static const String organization = 'Ministry of Statistics & Programme Implementation';

  // ─── Project Categories ───
  static const List<String> projectCategories = [
    'Roads',
    'Community Buildings',
    'Water Supply',
    'Education',
    'Healthcare',
    'Sanitation',
    'Other Public Assets',
  ];

  // ─── Investigation Statuses ───
  static const List<String> investigationStatuses = [
    'Pending Verification',
    'Under Investigation',
    'Field Verification',
    'Verified',
    'False Positive',
    'Escalated',
  ];

  // ─── Risk Levels for filters ───
  static const List<String> riskLevels = [
    'Critical',
    'High',
    'Medium',
    'Low',
  ];

  // ─── Anomaly Types ───
  static const List<String> anomalyTypes = [
    'Cost Anomaly',
    'Geo-Duplicate',
    'Execution Anomaly',
    'Image Similarity',
    'Rule Violation',
    'Timeline Anomaly',
  ];

  // ─── Demo Districts ───
  static const List<String> districts = [
    'Lucknow',
    'Jaipur',
    'Bhopal',
    'Patna',
    'Varanasi',
    'Pune',
    'Bengaluru',
    'Guwahati',
    'Chennai',
    'Hyderabad',
  ];
}
