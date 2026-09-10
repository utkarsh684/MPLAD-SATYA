import '../api/api_client.dart';
import '../models/evidence.dart';
import '../models/json.dart';
import '../models/risk.dart';
import '../models/satellite.dart';
import '../models/work.dart';

class WorksRepository {
  WorksRepository(this._api);
  final ApiClient _api;

  /// The server scopes results to the caller's district by role — there is no
  /// district filter to pass, and a client must not try to widen its own scope.
  Future<Paged<WorkSummary>> list({
    String? band,
    String? status,
    String? category,
    String? q,
    String? cursor,
    int limit = 25,
  }) async {
    final json = await _api.get('/works', query: {
      'limit': limit,
      if (cursor != null) 'cursor': cursor,
      if (band != null) 'band': band,
      if (status != null) 'status': status,
      if (category != null) 'category': category,
      if (q != null && q.isNotEmpty) 'q': q,
    });
    return Paged.fromJson(asMap(json), WorkSummary.fromJson);
  }

  Future<WorkDetail> detail(String workCode) async {
    final json = await _api.get('/works/${Uri.encodeComponent(workCode)}');
    return WorkDetail.fromJson(asMap(json));
  }

  Future<RiskAssessment> risk(String workCode) async {
    final json = await _api.get('/works/${Uri.encodeComponent(workCode)}/risk');
    return RiskAssessment.fromJson(asMap(json));
  }

  Future<List<RiskAssessment>> riskHistory(String workCode) async {
    final json =
        await _api.get('/works/${Uri.encodeComponent(workCode)}/risk/history');
    return asMapList(json).map(RiskAssessment.fromJson).toList();
  }

  /// Admin-only server-side; the UI hides the trigger for other roles.
  Future<RiskAssessment> recompute(String workCode) async {
    final json = await _api
        .post('/works/${Uri.encodeComponent(workCode)}/risk/recompute');
    return RiskAssessment.fromJson(asMap(json));
  }

  Future<Verification> verification(String workCode) async {
    final json =
        await _api.get('/works/${Uri.encodeComponent(workCode)}/verification');
    return Verification.fromJson(asMap(json));
  }

  Future<List<Evidence>> evidence(String workCode) async {
    final json =
        await _api.get('/works/${Uri.encodeComponent(workCode)}/evidence');
    return asMapList(json).map(Evidence.fromJson).toList();
  }

  /// Marker feed for the map. `bbox` is "minLon,minLat,maxLon,maxLat".
  Future<List<WorkSummary>> mapWorks({String? bbox, int limit = 500}) async {
    final json = await _api.get('/map/works', query: {
      'limit': limit,
      if (bbox != null) 'bbox': bbox,
    });
    return asMapList(json).map(WorkSummary.fromJson).toList();
  }

  // ---------------------------------------------------------------- eSAKSHI

  /// The official MoSPI works record for this work.
  Future<EsakshiRecord> esakshiRecord(String workCode) async {
    final json =
        await _api.get('/works/${Uri.encodeComponent(workCode)}/esakshi');
    return EsakshiRecord.fromJson(asMap(json));
  }

  /// Cross-check of our record against the official one.
  Future<EsakshiVerification> esakshiVerify(String workCode) async {
    final json = await _api
        .get('/works/${Uri.encodeComponent(workCode)}/esakshi/verify');
    return EsakshiVerification.fromJson(asMap(json));
  }

  // -------------------------------------------------------------- satellite

  /// Triggers an observation through the server's configured adapter (ISRO
  /// Bhuvan WMS when `SATELLITE_ADAPTER=bhuvan`, the offline fixture otherwise)
  /// and rescores the work with the result.
  Future<SatelliteResult> observeSatellite(String workCode) async {
    final json = await _api
        .post('/works/${Uri.encodeComponent(workCode)}/satellite/observe');
    return SatelliteResult.fromJson(asMap(json));
  }

  Future<List<SatelliteResult>> satelliteHistory(String workCode) async {
    final json = await _api
        .get('/works/${Uri.encodeComponent(workCode)}/satellite/history');
    return asMapList(json).map(SatelliteResult.fromJson).toList();
  }
}
