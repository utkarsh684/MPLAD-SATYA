import 'json.dart';
import 'money.dart';
import 'work.dart';

/// Mirrors `FundReleaseOut` — a tranche awaiting an officer's decision.
class FundRelease {
  final String id;
  final WorkSummary work;
  final int installmentNo;
  final String? trancheLabel;
  final Money claimedAmount;
  final String status;
  final DateTime? requestedAt;
  final String? evidenceSummary;

  const FundRelease({
    required this.id,
    required this.work,
    required this.installmentNo,
    required this.claimedAmount,
    required this.status,
    this.trancheLabel,
    this.requestedAt,
    this.evidenceSummary,
  });

  factory FundRelease.fromJson(Map<String, dynamic> json) => FundRelease(
        id: asString(json['id']),
        work: WorkSummary.fromJson(asMap(json['work'])),
        installmentNo: asInt(json['installment_no']),
        trancheLabel: asStringOrNull(json['tranche_label']),
        claimedAmount: Money.fromJson(json['claimed_amount']),
        status: asString(json['status']),
        requestedAt: asDate(json['requested_at']),
        evidenceSummary: asStringOrNull(json['evidence_summary']),
      );

  String get label => trancheLabel ?? 'Instalment $installmentNo';
}

/// The five actions the server accepts on a fund release.
enum DecisionAction {
  approve('approve', 'Approve Release'),
  hold('hold', 'Hold Release'),
  partialRelease('partial_release', 'Partial Release'),
  fieldReview('field_review', 'Send for Field Review'),
  reAudit('re_audit', 'Re-audit');

  const DecisionAction(this.wire, this.label);
  final String wire;
  final String label;
}

/// Mirrors `DecisionOut`. The AI score at the moment of decision is recorded
/// separately from the decision itself — evidence, not verdict.
class Decision {
  final String id;
  final String fundReleaseId;
  final String action;
  final int? aiScoreAtDecision;
  final String? aiRecommendationAtDecision;
  final DateTime? createdAt;
  final int? auditSeq;

  const Decision({
    required this.id,
    required this.fundReleaseId,
    required this.action,
    this.aiScoreAtDecision,
    this.aiRecommendationAtDecision,
    this.createdAt,
    this.auditSeq,
  });

  factory Decision.fromJson(Map<String, dynamic> json) => Decision(
        id: asString(json['id']),
        fundReleaseId: asString(json['fund_release_id']),
        action: asString(json['action']),
        aiScoreAtDecision: asIntOrNull(json['ai_score_at_decision']),
        aiRecommendationAtDecision:
            asStringOrNull(json['ai_recommendation_at_decision']),
        createdAt: asDate(json['created_at']),
        auditSeq: asIntOrNull(json['audit_seq']),
      );
}

/// Mirrors `DecisionSummaryOut` — the money counters on the decision queue.
class DecisionSummary {
  final Money totalSanctioned;
  final Money fundsHeld;
  final Money approvedForRelease;
  final Money pendingReview;
  final Map<String, int> counts;

  const DecisionSummary({
    required this.totalSanctioned,
    required this.fundsHeld,
    required this.approvedForRelease,
    required this.pendingReview,
    required this.counts,
  });

  factory DecisionSummary.fromJson(Map<String, dynamic> json) => DecisionSummary(
        totalSanctioned: Money.fromJson(json['total_sanctioned']),
        fundsHeld: Money.fromJson(json['funds_held']),
        approvedForRelease: Money.fromJson(json['approved_for_release']),
        pendingReview: Money.fromJson(json['pending_review']),
        counts: asMap(json['counts']).map((k, v) => MapEntry(k, asInt(v))),
      );
}
