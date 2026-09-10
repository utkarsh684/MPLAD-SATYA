import '../api/api_client.dart';
import '../models/decision.dart';
import '../models/json.dart';

class DecisionsRepository {
  DecisionsRepository(this._api);
  final ApiClient _api;

  Future<List<FundRelease>> queue({int limit = 50}) async {
    final json = await _api.get('/decisions/queue', query: {'limit': limit});
    return asMapList(json).map(FundRelease.fromJson).toList();
  }

  Future<DecisionSummary> summary() async {
    final json = await _api.get('/decisions/summary');
    return DecisionSummary.fromJson(asMap(json));
  }

  /// The server records the AI score at the moment of decision alongside the
  /// officer's action — approval stays an administrative act, not an AI verdict.
  Future<Decision> decide({
    required String releaseId,
    required DecisionAction action,
    String? justification,
    String? remarks,
    String? statutoryRef,
    int? partialPct,
  }) async {
    final json = await _api.post('/fund-releases/$releaseId/decision', body: {
      'action': action.wire,
      if (justification != null && justification.isNotEmpty)
        'justification': justification,
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
      if (statutoryRef != null && statutoryRef.isNotEmpty)
        'statutory_ref': statutoryRef,
      if (partialPct != null) 'partial_pct': partialPct,
    });
    return Decision.fromJson(asMap(json));
  }
}
