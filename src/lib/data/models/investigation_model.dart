import 'project_model.dart';
import 'evidence_model.dart';

/// Model representing an investigation case.
class InvestigationModel {
  final String id;
  final ProjectModel project;
  final int riskScore;
  final int confidenceScore;
  final String primaryAnomaly;
  final String primarySignalDescription;
  final String status;
  final DateTime flaggedDate;
  final List<EvidenceModel> evidence;
  final List<AuditEntry> auditTrail;

  const InvestigationModel({
    required this.id,
    required this.project,
    required this.riskScore,
    required this.confidenceScore,
    required this.primaryAnomaly,
    required this.primarySignalDescription,
    required this.status,
    required this.flaggedDate,
    required this.evidence,
    required this.auditTrail,
  });

  String get exposureLabel {
    if (riskScore >= 81 && confidenceScore >= 80) return 'Critical';
    if (riskScore >= 61) return 'High';
    if (riskScore >= 31) return 'Medium';
    return 'Low';
  }
}

/// A single entry in an audit trail.
class AuditEntry {
  final DateTime timestamp;
  final String action;
  final String actor;
  final String? hash;

  const AuditEntry({
    required this.timestamp,
    required this.action,
    required this.actor,
    this.hash,
  });
}
