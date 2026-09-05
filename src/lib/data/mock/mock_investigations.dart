import '../models/investigation_model.dart';
import '../models/evidence_model.dart';
import 'mock_projects.dart';
import 'mock_evidence.dart';

/// Mock investigations data.
class MockInvestigations {
  MockInvestigations._();

  static List<InvestigationModel> get all => [
    // ─── HERO INVESTIGATION — Community Hall ───
    InvestigationModel(
      id: 'INV-2026-0001',
      project: MockProjects.all[0], // Community Hall
      riskScore: 94,
      confidenceScore: 89,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Cost significantly above peer-group median. Expenditure-progress mismatch detected.',
      status: 'Pending Verification',
      flaggedDate: DateTime(2026, 8, 28, 10, 42),
      evidence: MockEvidence.communityHallEvidence,
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 28, 10, 42),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'a83f4e2d1b7c9f0e...91bc',
        ),
        AuditEntry(
          timestamp: DateTime(2026, 8, 28, 10, 47),
          action: 'Investigation created',
          actor: 'System',
          hash: 'b92e5d3a8c1f7e4b...a2cd',
        ),
        AuditEntry(
          timestamp: DateTime(2026, 8, 29, 11, 13),
          action: 'Officer opened investigation',
          actor: 'Officer Demo (ID: OFF-001)',
          hash: 'c71d6f4b9a2e8c3d...b3de',
        ),
      ],
    ),

    // ─── CC Road Construction ───
    InvestigationModel(
      id: 'INV-2026-0002',
      project: MockProjects.all[14], // CC Road Ward 12
      riskScore: 91,
      confidenceScore: 87,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Road construction cost 2.8× CPWD rate. 96% expenditure with 38% physical progress.',
      status: 'Under Investigation',
      flaggedDate: DateTime(2026, 8, 25, 14, 30),
      evidence: MockEvidence.ccRoadEvidence,
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 25, 14, 30),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'd63c7a1e5b4f9d2c...c4ef',
        ),
        AuditEntry(
          timestamp: DateTime(2026, 8, 26, 9, 15),
          action: 'Officer assigned to investigation',
          actor: 'System',
          hash: 'e54b8c2f6a3e7d1b...d5fa',
        ),
      ],
    ),

    // ─── Panchayat Bhawan ───
    InvestigationModel(
      id: 'INV-2026-0003',
      project: MockProjects.all[10], // Panchayat Bhawan
      riskScore: 88,
      confidenceScore: 82,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Sanctioned 2.48× recommended amount. Major expenditure-progress gap.',
      status: 'Pending Verification',
      flaggedDate: DateTime(2026, 8, 22, 16, 0),
      evidence: MockEvidence.panchayatBhawanEvidence,
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 22, 16, 0),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'f45a9d3c7b2e6f1a...e6ab',
        ),
      ],
    ),

    // ─── PHC Equipment ───
    InvestigationModel(
      id: 'INV-2026-0004',
      project: MockProjects.all[4], // PHC Equipment
      riskScore: 85,
      confidenceScore: 76,
      primaryAnomaly: 'Rule Violation',
      primarySignalDescription:
          'Equipment procurement 2.5× recommended without tender documentation.',
      status: 'Under Investigation',
      flaggedDate: DateTime(2026, 8, 20, 11, 20),
      evidence: MockEvidence.phcEquipmentEvidence,
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 20, 11, 20),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'a12b3c4d5e6f7890...f7bc',
        ),
      ],
    ),

    // ─── Bus Stop Shelter ───
    InvestigationModel(
      id: 'INV-2026-0005',
      project: MockProjects.all[9], // Bus Stop
      riskScore: 78,
      confidenceScore: 86,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Shelter cost 2.5× recommended amount for a standard bus stop structure.',
      status: 'Field Verification',
      flaggedDate: DateTime(2026, 8, 18, 9, 45),
      evidence: const [
        EvidenceModel(
          id: 'EVD-501',
          anomalyType: 'Cost Anomaly',
          severity: 'High',
          explanation: 'Bus stop shelter cost at ₹12.5L is 2.5× the recommended ₹5L.',
          supportingMetric: '₹12.5L vs ₹5L recommended',
          evidenceSource: 'CPWD rate comparison',
          confidence: 86,
          riskContribution: 28,
        ),
      ],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 18, 9, 45),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'b23c4d5e6f7a8901...a8cd',
        ),
        AuditEntry(
          timestamp: DateTime(2026, 8, 19, 10, 0),
          action: 'Field verification requested',
          actor: 'Officer Demo',
          hash: 'c34d5e6f7a8b9012...b9de',
        ),
      ],
    ),

    // ─── School Renovation ───
    InvestigationModel(
      id: 'INV-2026-0006',
      project: MockProjects.all[1], // School Renovation
      riskScore: 72,
      confidenceScore: 84,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Renovation cost 1.8× peer median with delayed timeline.',
      status: 'Under Investigation',
      flaggedDate: DateTime(2026, 8, 15, 13, 10),
      evidence: MockEvidence.schoolRenovationEvidence,
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 15, 13, 10),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'd45e6f7a8b9c0123...c0ef',
        ),
      ],
    ),

    // ─── Community Toilet ───
    InvestigationModel(
      id: 'INV-2026-0007',
      project: MockProjects.all[7], // Community Toilet
      riskScore: 67,
      confidenceScore: 81,
      primaryAnomaly: 'Execution Anomaly',
      primarySignalDescription:
          'Full expenditure disbursed with only 30% physical progress.',
      status: 'Pending Verification',
      flaggedDate: DateTime(2026, 8, 12, 15, 30),
      evidence: const [
        EvidenceModel(
          id: 'EVD-601',
          anomalyType: 'Execution Anomaly',
          severity: 'High',
          explanation: '100% funds disbursed while physical progress is at 30%.',
          supportingMetric: '100% expenditure vs 30% progress',
          evidenceSource: 'Progress monitoring',
          confidence: 81,
          riskContribution: 30,
        ),
      ],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 12, 15, 30),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'e56f7a8b9c0d1234...d1fa',
        ),
      ],
    ),

    // ─── Flood Embankment ───
    InvestigationModel(
      id: 'INV-2026-0008',
      project: MockProjects.all[17], // Flood Relief
      riskScore: 52,
      confidenceScore: 74,
      primaryAnomaly: 'Timeline Anomaly',
      primarySignalDescription:
          'Project timeline extended beyond planned completion with moderate progress.',
      status: 'Under Investigation',
      flaggedDate: DateTime(2026, 8, 10, 10, 0),
      evidence: const [
        EvidenceModel(
          id: 'EVD-701',
          anomalyType: 'Timeline Anomaly',
          severity: 'Medium',
          explanation: 'Project 45% complete after 80% of planned duration elapsed.',
          supportingMetric: '45% progress at 80% timeline',
          evidenceSource: 'Timeline analysis',
          confidence: 74,
          riskContribution: 20,
        ),
      ],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 10, 10, 0),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'f67a8b9c0d1e2345...e2ab',
        ),
      ],
    ),

    // ─── Drainage (Medium Risk) ───
    InvestigationModel(
      id: 'INV-2026-0009',
      project: MockProjects.all[5], // Drainage
      riskScore: 45,
      confidenceScore: 72,
      primaryAnomaly: 'Timeline Anomaly',
      primarySignalDescription:
          'Drainage project showing slower than expected progress.',
      status: 'Under Investigation',
      flaggedDate: DateTime(2026, 8, 8, 14, 15),
      evidence: const [
        EvidenceModel(
          id: 'EVD-801',
          anomalyType: 'Timeline Anomaly',
          severity: 'Medium',
          explanation: '35% progress at halfway point of the project timeline.',
          supportingMetric: '35% progress at 50% timeline',
          evidenceSource: 'Timeline tracking',
          confidence: 72,
          riskContribution: 18,
        ),
      ],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 8, 14, 15),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'a78b9c0d1e2f3456...f3bc',
        ),
      ],
    ),

    // ─── Footpath (Low-Medium) ───
    InvestigationModel(
      id: 'INV-2026-0010',
      project: MockProjects.all[19], // Footpath
      riskScore: 35,
      confidenceScore: 80,
      primaryAnomaly: 'Cost Anomaly',
      primarySignalDescription:
          'Minor cost deviation above district average for footpath works.',
      status: 'Verified',
      flaggedDate: DateTime(2026, 8, 5, 11, 0),
      evidence: const [
        EvidenceModel(
          id: 'EVD-901',
          anomalyType: 'Cost Anomaly',
          severity: 'Low',
          explanation: 'Cost slightly above average for footpath construction.',
          supportingMetric: '₹13L vs ₹11L average',
          evidenceSource: 'Cost analysis',
          confidence: 80,
          riskContribution: 12,
        ),
      ],
      auditTrail: [
        AuditEntry(
          timestamp: DateTime(2026, 8, 5, 11, 0),
          action: 'Project flagged by AI screening',
          actor: 'SATYA AI Engine',
          hash: 'b89c0d1e2f3a4567...a4cd',
        ),
        AuditEntry(
          timestamp: DateTime(2026, 8, 6, 10, 30),
          action: 'Officer reviewed - Verified as acceptable',
          actor: 'Officer Demo',
          hash: 'c90d1e2f3a4b5678...b5de',
        ),
      ],
    ),
  ];

  /// Get the hero (most impressive) investigation.
  static InvestigationModel get hero => all.first;
}
