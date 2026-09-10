import '../api/api_client.dart';
import '../models/analytics.dart';
import '../models/json.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._api);
  final ApiClient _api;

  Future<AnalyticsOverview> overview() async {
    final json = await _api.get('/analytics/overview');
    return AnalyticsOverview.fromJson(asMap(json));
  }

  Future<List<CategoryRisk>> categoryRisk() async {
    final json = await _api.get('/analytics/category-risk');
    return asMapList(json).map(CategoryRisk.fromJson).toList();
  }

  Future<List<DistrictSummary>> districtSummary() async {
    final json = await _api.get('/analytics/district-summary');
    return asMapList(json).map(DistrictSummary.fromJson).toList();
  }

  Future<List<TopRiskWork>> topRisk({int limit = 20}) async {
    final json = await _api.get('/analytics/top-risk', query: {'limit': limit});
    return asMapList(json).map(TopRiskWork.fromJson).toList();
  }

  Future<List<RuleFrequency>> ruleFrequency() async {
    final json = await _api.get('/analytics/rule-frequency');
    return asMapList(json).map(RuleFrequency.fromJson).toList();
  }

  /// Liveness plus the rulebook digest this instance is running.
  Future<ServerStatus> status() async {
    final json = await _api.getRoot('/readyz');
    return ServerStatus.fromJson(asMap(json));
  }

  /// Walks the audit hash chain and re-verifies every link.
  Future<AuditVerification> verifyAuditChain() async {
    final json = await _api.get('/audit/verify');
    return AuditVerification.fromJson(asMap(json));
  }

  /// The full rulebook, public by design: rules, weights and their digests.
  Future<Map<String, dynamic>> rulebook() async {
    final json = await _api.get('/admin/rules');
    return asMap(json);
  }
}
