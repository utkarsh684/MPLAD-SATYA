import '../models/report_model.dart';

/// Mock reports for the reports screen.
class MockReports {
  MockReports._();

  static final List<ReportModel> all = [
    ReportModel(
      id: 'RPT-001',
      title: 'District Risk Report',
      type: 'District Risk',
      generatedDate: DateTime(2026, 8, 28),
      projectsCovered: 486,
      riskSummary: '76 Critical, 142 High, 180 Medium, 88 Low',
      description:
          'Comprehensive risk assessment of all MPLADS projects across the district. Includes anomaly distribution, trend analysis, and recommended actions.',
    ),
    ReportModel(
      id: 'RPT-002',
      title: 'High-Risk Projects',
      type: 'High Risk',
      generatedDate: DateTime(2026, 8, 27),
      projectsCovered: 218,
      riskSummary: '76 Critical, 142 High Risk projects requiring attention',
      description:
          'Detailed breakdown of all high-risk and critical projects. Sorted by risk score with primary anomaly signals.',
    ),
    ReportModel(
      id: 'RPT-003',
      title: 'Field Verification Report',
      type: 'Field Verification',
      generatedDate: DateTime(2026, 8, 25),
      projectsCovered: 34,
      riskSummary: '12 Verified, 8 Pending, 14 In Progress',
      description:
          'Status of field verifications including evidence collected, GPS verification, and photo documentation.',
    ),
    ReportModel(
      id: 'RPT-004',
      title: 'Investigation Summary',
      type: 'Investigation',
      generatedDate: DateTime(2026, 8, 26),
      projectsCovered: 52,
      riskSummary: '10 Resolved, 18 Under Investigation, 24 Pending',
      description:
          'Summary of all investigation cases including officer decisions, audit trail completeness, and escalation status.',
    ),
    ReportModel(
      id: 'RPT-005',
      title: 'Monthly Anomaly Report',
      type: 'Monthly',
      generatedDate: DateTime(2026, 8, 1),
      projectsCovered: 1240,
      riskSummary: 'August 2026: 48 new anomalies detected, 22 resolved',
      description:
          'Monthly overview of anomaly detection patterns, new flagged projects, resolution rates, and AI model performance.',
    ),
  ];
}
