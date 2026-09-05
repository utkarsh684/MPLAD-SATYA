import '../models/evidence_model.dart';

/// Mock evidence records for investigations.
class MockEvidence {
  MockEvidence._();

  // ─── Evidence for hero investigation (Community Hall, MPL-2026-00482) ───
  static final List<EvidenceModel> communityHallEvidence = [
    const EvidenceModel(
      id: 'EVD-001',
      anomalyType: 'Cost Anomaly',
      severity: 'Critical',
      explanation:
          'Project cost is 2.4× the median cost of comparable community building works in the same district, category and financial year.',
      supportingMetric: '₹82L actual vs ₹34L peer median',
      evidenceSource: 'Project expenditure record vs CPWD rate analysis',
      confidence: 91,
      riskContribution: 28,
      chartData: {
        'thisProject': 82.0,
        'peerMedian': 34.0,
        'peerP75': 42.0,
        'peerP90': 55.0,
      },
    ),
    const EvidenceModel(
      id: 'EVD-002',
      anomalyType: 'Execution Anomaly',
      severity: 'High',
      explanation:
          '82% expenditure reported while physical progress is only 41%. The expenditure-to-progress ratio of 2.0x significantly exceeds the expected 1.0x threshold.',
      supportingMetric: '82% expenditure vs 41% progress',
      evidenceSource: 'eSAKSHI progress report',
      confidence: 87,
      riskContribution: 24,
      chartData: {
        'expenditurePercent': 82.0,
        'progressPercent': 41.0,
      },
    ),
    const EvidenceModel(
      id: 'EVD-003',
      anomalyType: 'Geo-Duplicate',
      severity: 'High',
      explanation:
          'A highly similar project (Panchayat Bhawan, MPL-2026-01205) exists within 1.4 km. Both projects are community buildings in the same district with overlapping timelines.',
      supportingMetric: 'Distance: 1.4 km | Similarity: 87%',
      evidenceSource: 'Geospatial analysis (Haversine)',
      confidence: 83,
      riskContribution: 18,
    ),
    const EvidenceModel(
      id: 'EVD-004',
      anomalyType: 'Image Similarity',
      severity: 'Medium',
      explanation:
          'Uploaded progress photo shows 92% perceptual similarity with an image from project MPL-2026-01205. This may indicate reuse of progress imagery.',
      supportingMetric: 'pHash similarity: 92%',
      evidenceSource: 'Image analysis (pHash + CLIP)',
      confidence: 78,
      riskContribution: 14,
      imageUrls: ['progress_photo_1.jpg', 'similar_photo_ref.jpg'],
    ),
    const EvidenceModel(
      id: 'EVD-005',
      anomalyType: 'Rule Violation',
      severity: 'Medium',
      explanation:
          'Project sanctioned amount (₹82L) exceeds the recommended amount (₹35L) by 134%. Projects exceeding recommended amounts by more than 50% require additional justification under applicable guidelines.',
      supportingMetric: '₹82L sanctioned vs ₹35L recommended (134% excess)',
      evidenceSource: 'MPLADS Guidelines compliance check',
      confidence: 95,
      riskContribution: 10,
    ),
  ];

  // ─── Evidence sets for other investigations ───
  static final List<EvidenceModel> schoolRenovationEvidence = [
    const EvidenceModel(
      id: 'EVD-101',
      anomalyType: 'Cost Anomaly',
      severity: 'High',
      explanation:
          'Renovation cost is 1.8× the median for comparable school renovation works in the district.',
      supportingMetric: '₹22.5L actual vs ₹12.5L peer median',
      evidenceSource: 'CPWD rate comparison',
      confidence: 84,
      riskContribution: 22,
    ),
    const EvidenceModel(
      id: 'EVD-102',
      anomalyType: 'Timeline Anomaly',
      severity: 'Medium',
      explanation:
          'Project has been in progress for 20 months against a planned 12-month timeline. No extension has been formally recorded.',
      supportingMetric: '20 months elapsed vs 12 months planned',
      evidenceSource: 'Timeline tracking',
      confidence: 90,
      riskContribution: 18,
    ),
  ];

  static final List<EvidenceModel> phcEquipmentEvidence = [
    const EvidenceModel(
      id: 'EVD-201',
      anomalyType: 'Cost Anomaly',
      severity: 'Critical',
      explanation:
          'Equipment procurement cost is 2.5× the recommended amount. No tender documentation found for equipment above ₹5L.',
      supportingMetric: '₹38L sanctioned vs ₹15L recommended',
      evidenceSource: 'Procurement records',
      confidence: 76,
      riskContribution: 30,
    ),
    const EvidenceModel(
      id: 'EVD-202',
      anomalyType: 'Rule Violation',
      severity: 'High',
      explanation:
          'Equipment procurement above ₹5L requires tender as per guidelines. No tender record found.',
      supportingMetric: 'Missing tender for ₹38L procurement',
      evidenceSource: 'MPLADS Guidelines Annex-II',
      confidence: 88,
      riskContribution: 25,
    ),
  ];

  static final List<EvidenceModel> ccRoadEvidence = [
    const EvidenceModel(
      id: 'EVD-301',
      anomalyType: 'Cost Anomaly',
      severity: 'Critical',
      explanation:
          'CC Road cost is 2.8× the CPWD rate for similar road construction in Varanasi district.',
      supportingMetric: '₹42L actual vs ₹15L CPWD rate',
      evidenceSource: 'CPWD rate schedule comparison',
      confidence: 92,
      riskContribution: 30,
    ),
    const EvidenceModel(
      id: 'EVD-302',
      anomalyType: 'Execution Anomaly',
      severity: 'High',
      explanation:
          '96% expenditure disbursed while physical progress stands at only 38%.',
      supportingMetric: '96% expenditure vs 38% progress',
      evidenceSource: 'Progress monitoring',
      confidence: 89,
      riskContribution: 26,
    ),
    const EvidenceModel(
      id: 'EVD-303',
      anomalyType: 'Image Similarity',
      severity: 'Medium',
      explanation:
          'Progress photos appear to show pre-existing road surface rather than new construction.',
      supportingMetric: 'AI image analysis confidence: 74%',
      evidenceSource: 'Image analysis',
      confidence: 74,
      riskContribution: 12,
    ),
  ];

  static final List<EvidenceModel> panchayatBhawanEvidence = [
    const EvidenceModel(
      id: 'EVD-401',
      anomalyType: 'Cost Anomaly',
      severity: 'Critical',
      explanation:
          'Sanctioned amount is 2.48× the recommended amount for this panchayat building.',
      supportingMetric: '₹62L sanctioned vs ₹25L recommended',
      evidenceSource: 'Financial records',
      confidence: 90,
      riskContribution: 28,
    ),
    const EvidenceModel(
      id: 'EVD-402',
      anomalyType: 'Execution Anomaly',
      severity: 'High',
      explanation:
          'Expenditure at 93.5% while physical progress is 48%.',
      supportingMetric: '93.5% expenditure vs 48% progress',
      evidenceSource: 'eSAKSHI progress report',
      confidence: 86,
      riskContribution: 24,
    ),
    const EvidenceModel(
      id: 'EVD-403',
      anomalyType: 'Geo-Duplicate',
      severity: 'High',
      explanation:
          'Another community building project (Community Hall, MPL-2026-00482) exists within 1.4 km in the same district.',
      supportingMetric: 'Distance: 1.4 km',
      evidenceSource: 'Geospatial duplicate detection',
      confidence: 83,
      riskContribution: 16,
    ),
  ];

  /// All evidence records combined.
  static List<EvidenceModel> get all => [
        ...communityHallEvidence,
        ...schoolRenovationEvidence,
        ...phcEquipmentEvidence,
        ...ccRoadEvidence,
        ...panchayatBhawanEvidence,
      ];
}
