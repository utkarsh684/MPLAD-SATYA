/// Model representing an MPLADS project.
class ProjectModel {
  final String id;
  final String name;
  final String village;
  final String district;
  final String state;
  final String category;
  final double recommendedAmount; // in lakhs
  final double sanctionedAmount;
  final double expenditure;
  final double physicalProgress; // 0-100
  final DateTime startDate;
  final DateTime expectedCompletion;
  final String status;
  final int riskScore;
  final int confidenceScore;
  final String mpName;
  final String implementingAgency;
  final double latitude;
  final double longitude;

  const ProjectModel({
    required this.id,
    required this.name,
    required this.village,
    required this.district,
    required this.state,
    required this.category,
    required this.recommendedAmount,
    required this.sanctionedAmount,
    required this.expenditure,
    required this.physicalProgress,
    required this.startDate,
    required this.expectedCompletion,
    required this.status,
    required this.riskScore,
    required this.confidenceScore,
    required this.mpName,
    required this.implementingAgency,
    required this.latitude,
    required this.longitude,
  });

  String get exposureLabel {
    if (riskScore >= 81 && confidenceScore >= 80) return 'Critical';
    if (riskScore >= 61) return 'High';
    if (riskScore >= 31) return 'Medium';
    return 'Low';
  }

  String get formattedRecommended => '₹${recommendedAmount.toStringAsFixed(1)}L';
  String get formattedSanctioned => '₹${sanctionedAmount.toStringAsFixed(1)}L';
  String get formattedExpenditure => '₹${expenditure.toStringAsFixed(1)}L';
}
