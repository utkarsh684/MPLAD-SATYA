/// Model representing a piece of evidence for an anomaly.
class EvidenceModel {
  final String id;
  final String anomalyType; // Cost Anomaly, Geo-Duplicate, etc.
  final String severity; // Low, Medium, High, Critical
  final String explanation;
  final String supportingMetric;
  final String evidenceSource;
  final int confidence;
  final int riskContribution; // how much this adds to overall risk
  final Map<String, dynamic>? chartData; // for inline visualizations
  final List<String>? imageUrls; // for image similarity evidence

  const EvidenceModel({
    required this.id,
    required this.anomalyType,
    required this.severity,
    required this.explanation,
    required this.supportingMetric,
    required this.evidenceSource,
    required this.confidence,
    required this.riskContribution,
    this.chartData,
    this.imageUrls,
  });
}
