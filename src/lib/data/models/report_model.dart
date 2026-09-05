/// Model representing a report.
class ReportModel {
  final String id;
  final String title;
  final String type;
  final DateTime generatedDate;
  final int projectsCovered;
  final String riskSummary;
  final String description;

  const ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.generatedDate,
    required this.projectsCovered,
    required this.riskSummary,
    required this.description,
  });
}
