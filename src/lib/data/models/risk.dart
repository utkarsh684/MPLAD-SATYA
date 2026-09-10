import 'json.dart';
import 'work.dart';

/// One line of the "why was this flagged" list.
///
/// `points` is load-bearing: the server apportions reason points so they sum
/// exactly to the gauge score. The UI must never rescale or re-sort them.
class RiskReason {
  final int rank;
  final String code;
  final String category;
  final String severity;
  final String title;
  final int points;
  final String explanation;
  final String provenance;
  final Map<String, dynamic> refs;

  const RiskReason({
    required this.rank,
    required this.code,
    required this.category,
    required this.severity,
    required this.title,
    required this.points,
    required this.explanation,
    required this.provenance,
    this.refs = const {},
  });

  factory RiskReason.fromJson(Map<String, dynamic> json) => RiskReason(
        rank: asInt(json['rank']),
        code: asString(json['code']),
        category: asString(json['category']),
        severity: asString(json['severity']),
        title: asString(json['title']),
        points: asInt(json['points']),
        explanation: asString(json['explanation']),
        provenance: asString(json['provenance']),
        refs: asMap(json['refs']),
      );
}

/// Mirrors `RiskAssessmentOut`.
class RiskAssessment {
  final String id;
  final String workId;
  final String workCode;
  final int score;
  final String band;
  final String bandLabel;
  final String recommendedAction;
  final String actionLabel;

  /// Server-owned so a client build cannot drop it. Always render it.
  final String disclaimer;
  final int? consistencyPct;
  final Map<String, int> subscores;
  final List<RiskReason> reasons;
  final String engineVersion;
  final String rulesSha256;
  final DateTime? computedAt;

  const RiskAssessment({
    required this.id,
    required this.workId,
    required this.workCode,
    required this.score,
    required this.band,
    required this.bandLabel,
    required this.recommendedAction,
    required this.actionLabel,
    required this.disclaimer,
    required this.subscores,
    required this.reasons,
    required this.engineVersion,
    required this.rulesSha256,
    this.consistencyPct,
    this.computedAt,
  });

  factory RiskAssessment.fromJson(Map<String, dynamic> json) => RiskAssessment(
        id: asString(json['id']),
        workId: asString(json['work_id']),
        workCode: asString(json['work_code']),
        score: asInt(json['score']),
        band: asString(json['band']),
        bandLabel: asString(json['band_label']),
        recommendedAction: asString(json['recommended_action']),
        actionLabel: asString(json['action_label']),
        disclaimer: asString(json['disclaimer']),
        consistencyPct: asIntOrNull(json['consistency_pct']),
        subscores: asMap(json['subscores'])
            .map((k, v) => MapEntry(k, asInt(v))),
        reasons: asMapList(json['reasons']).map(RiskReason.fromJson).toList(),
        engineVersion: asString(json['engine_version']),
        rulesSha256: asString(json['rules_sha256']),
        computedAt: asDate(json['computed_at']),
      );

  /// Proof that the explanation is arithmetic, not hand-waving. Shown in the
  /// UI so a judge can add up the reasons themselves.
  int get reasonPointsTotal =>
      reasons.fold(0, (sum, r) => sum + r.points);
}

/// One of the four evidence source cards.
class SourceCard {
  /// `official_record` | `satellite` | `citizen` | `field`
  final String source;

  /// `available` | `match` | `mismatch` | `inconclusive` | `unavailable`
  final String status;
  final String headline;
  final double? confidence;
  final double? observedValue;
  final double? expectedValue;
  final String? observedUnit;
  final int reportCount;

  const SourceCard({
    required this.source,
    required this.status,
    required this.headline,
    required this.reportCount,
    this.confidence,
    this.observedValue,
    this.expectedValue,
    this.observedUnit,
  });

  factory SourceCard.fromJson(Map<String, dynamic> json) => SourceCard(
        source: asString(json['source']),
        status: asString(json['status']),
        headline: asString(json['headline']),
        confidence: asDoubleOrNull(json['confidence']),
        observedValue: asDoubleOrNull(json['observed_value']),
        expectedValue: asDoubleOrNull(json['expected_value']),
        observedUnit: asStringOrNull(json['observed_unit']),
        reportCount: asInt(json['report_count']),
      );

  /// "the sensor cannot see this" is not evidence of wrongdoing. Inconclusive
  /// and unavailable sources are excluded from the consistency calculation
  /// server-side, and the UI must not colour them as risk either.
  bool get isInformative => status == 'match' || status == 'mismatch';

  bool get contradicts => status == 'mismatch';

  String get statusLabel => switch (status) {
        'available' => 'Available',
        'match' => 'Consistent',
        'mismatch' => 'Discrepancy',
        'inconclusive' => 'Inconclusive',
        'unavailable' => 'No data',
        _ => status,
      };

  String get sourceLabel => switch (source) {
        'official_record' => 'Official Record',
        'satellite' => 'Satellite',
        'citizen' => 'Citizen Reports',
        'field' => 'Field Verification',
        _ => source,
      };
}

/// Mirrors `VerificationOut` — the four-source screen.
class Verification {
  final WorkSummary work;
  final int? score;
  final String? band;
  final int? consistencyPct;
  final List<SourceCard> sources;

  const Verification({
    required this.work,
    required this.sources,
    this.score,
    this.band,
    this.consistencyPct,
  });

  factory Verification.fromJson(Map<String, dynamic> json) => Verification(
        work: WorkSummary.fromJson(asMap(json['work'])),
        score: asIntOrNull(json['score']),
        band: asStringOrNull(json['band']),
        consistencyPct: asIntOrNull(json['consistency_pct']),
        sources:
            asMapList(json['sources']).map(SourceCard.fromJson).toList(),
      );
}
