import 'dart:io';

import '../api/api_client.dart';
import '../models/dashboard.dart';
import '../models/evidence.dart';
import '../models/json.dart';

class FieldRepository {
  FieldRepository(this._api);
  final ApiClient _api;

  Future<FieldDashboard> dashboard() async {
    final json = await _api.get('/me/dashboard');
    return FieldDashboard.fromJson(asMap(json));
  }

  /// Priority queue: the server sorts highest risk first, then soonest due.
  /// Passing the officer's position adds a real `distance_m` to each item.
  Future<List<Assignment>> myVerifications({
    double? lat,
    double? lon,
    int limit = 20,
  }) async {
    final json = await _api.get('/me/verifications', query: {
      'limit': limit,
      if (lat != null) 'lat': lat,
      if (lon != null) 'lon': lon,
    });
    return asMapList(json).map(Assignment.fromJson).toList();
  }

  Future<Assignment> start(String verificationId) async {
    final json = await _api.post('/verifications/$verificationId/start');
    return Assignment.fromJson(asMap(json));
  }

  /// Idempotent on [clientUuid] so an offline queue can replay safely.
  Future<Map<String, dynamic>> submit({
    required String verificationId,
    required String clientUuid,
    required String observedStatus,
    double? measuredValue,
    String? measuredUnit,
    String? measureMethod,
    double? measureAccuracyM,
    double? lat,
    double? lon,
    String? notes,
    List<String> evidenceIds = const [],
  }) async {
    final json = await _api.post(
      '/verifications/$verificationId/submit',
      body: {
        'client_uuid': clientUuid,
        'observed_status': observedStatus,
        if (measuredValue != null) 'measured_value': measuredValue,
        if (measuredUnit != null) 'measured_unit': measuredUnit,
        if (measureMethod != null) 'measure_method': measureMethod,
        if (measureAccuracyM != null) 'measure_accuracy_m': measureAccuracyM,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'evidence_ids': evidenceIds,
      },
    );
    return asMap(json);
  }

  /// Uploads a photo through the full server pipeline: sha256, EXIF, GPS trust,
  /// face blur, pHash, storage, then a risk rescore.
  Future<Evidence> uploadEvidence({
    required String workCode,
    required File photo,
    required String clientUuid,
    String source = 'field_officer',
    bool isMockLocation = false,
    double? claimedAccuracyM,
  }) async {
    final json = await _api.postFile(
      '/works/${Uri.encodeComponent(workCode)}/evidence',
      file: photo,
      fieldName: 'file',
      fields: {
        'source': source,
        'client_uuid': clientUuid,
        'is_mock_location': '$isMockLocation',
        if (claimedAccuracyM != null) 'claimed_accuracy_m': '$claimedAccuracyM',
      },
    );
    return Evidence.fromJson(asMap(json));
  }
}
