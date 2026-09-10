import 'json.dart';
import 'money.dart';

/// `GET /analytics/overview`.
class AnalyticsOverview {
  final int totalWorks;
  final int green;
  final int yellow;
  final int red;
  final double averageRiskScore;
  final Money totalSanctioned;
  final int pendingFundReleases;
  final int totalEvidenceItems;
  final int totalDecisions;

  const AnalyticsOverview({
    required this.totalWorks,
    required this.green,
    required this.yellow,
    required this.red,
    required this.averageRiskScore,
    required this.totalSanctioned,
    required this.pendingFundReleases,
    required this.totalEvidenceItems,
    required this.totalDecisions,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    final bands = asMap(json['by_band']);
    return AnalyticsOverview(
      totalWorks: asInt(json['total_works']),
      green: asInt(bands['green']),
      yellow: asInt(bands['yellow']),
      red: asInt(bands['red']),
      averageRiskScore: asDouble(json['average_risk_score']),
      totalSanctioned: Money.fromJson(json['total_sanctioned_paise']),
      pendingFundReleases: asInt(json['pending_fund_releases']),
      totalEvidenceItems: asInt(json['total_evidence_items']),
      totalDecisions: asInt(json['total_decisions']),
    );
  }

  /// Works that actually carry an assessment. A work with no assessment is not
  /// a low-risk work, so the pie is drawn over this, not over [totalWorks].
  int get assessedWorks => green + yellow + red;

  bool get hasAssessments => assessedWorks > 0;
}

/// `GET /analytics/category-risk`.
class CategoryRisk {
  final String category;
  final int count;
  final double avgScore;
  final int maxScore;

  const CategoryRisk({
    required this.category,
    required this.count,
    required this.avgScore,
    required this.maxScore,
  });

  factory CategoryRisk.fromJson(Map<String, dynamic> json) => CategoryRisk(
        category: asString(json['category']),
        count: asInt(json['count']),
        avgScore: asDouble(json['avg_score']),
        maxScore: asInt(json['max_score']),
      );
}

/// `GET /analytics/district-summary`.
class DistrictSummary {
  final String district;
  final int works;
  final Money totalSanctioned;
  final double avgRiskScore;

  const DistrictSummary({
    required this.district,
    required this.works,
    required this.totalSanctioned,
    required this.avgRiskScore,
  });

  factory DistrictSummary.fromJson(Map<String, dynamic> json) => DistrictSummary(
        district: asString(json['district']),
        works: asInt(json['works']),
        totalSanctioned: Money.fromJson(json['total_sanctioned_paise']),
        avgRiskScore: asDouble(json['avg_risk_score']),
      );
}

/// `GET /analytics/top-risk`.
class TopRiskWork {
  final String workCode;
  final String title;
  final String category;
  final int score;
  final String band;

  const TopRiskWork({
    required this.workCode,
    required this.title,
    required this.category,
    required this.score,
    required this.band,
  });

  factory TopRiskWork.fromJson(Map<String, dynamic> json) => TopRiskWork(
        workCode: asString(json['work_code']),
        title: asString(json['title']),
        category: asString(json['category']),
        score: asInt(json['score']),
        band: asString(json['band']),
      );
}

/// `GET /analytics/rule-frequency` — which rules actually fire in this dataset.
class RuleFrequency {
  final String code;
  final String category;
  final int fires;
  final double avgPoints;

  const RuleFrequency({
    required this.code,
    required this.category,
    required this.fires,
    required this.avgPoints,
  });

  factory RuleFrequency.fromJson(Map<String, dynamic> json) => RuleFrequency(
        code: asString(json['code']),
        category: asString(json['category']),
        fires: asInt(json['fires']),
        avgPoints: asDouble(json['avg_points']),
      );
}

/// `GET /readyz` — the app shows the demo flag rather than hiding it.
class ServerStatus {
  final String status;
  final String engineVersion;
  final String rulesSha256;
  final bool demoMode;
  final String env;
  final String? db;

  const ServerStatus({
    required this.status,
    required this.engineVersion,
    required this.rulesSha256,
    required this.demoMode,
    required this.env,
    this.db,
  });

  factory ServerStatus.fromJson(Map<String, dynamic> json) => ServerStatus(
        status: asString(json['status']),
        engineVersion: asString(json['engine_version']),
        rulesSha256: asString(json['rules_sha256']),
        demoMode: asBool(json['demo_mode']),
        env: asString(json['env']),
        db: asStringOrNull(json['db']),
      );

  String get shortRulesSha =>
      rulesSha256.length >= 12 ? rulesSha256.substring(0, 12) : rulesSha256;
}

/// `GET /audit/verify` — the chain integrity check, run live on stage.
class AuditVerification {
  final bool valid;
  final int checked;
  final int? firstSeq;
  final int? lastSeq;
  final String? headHash;
  final int? brokenAtSeq;
  final String? problem;

  const AuditVerification({
    required this.valid,
    required this.checked,
    this.firstSeq,
    this.lastSeq,
    this.headHash,
    this.brokenAtSeq,
    this.problem,
  });

  factory AuditVerification.fromJson(Map<String, dynamic> json) => AuditVerification(
        valid: asBool(json['valid']),
        checked: asInt(json['checked']),
        firstSeq: asIntOrNull(json['first_seq']),
        lastSeq: asIntOrNull(json['last_seq']),
        headHash: asStringOrNull(json['head_hash']),
        brokenAtSeq: asIntOrNull(json['broken_at_seq']),
        problem: asStringOrNull(json['problem']),
      );
}
