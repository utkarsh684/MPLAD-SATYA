import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/device_id.dart';
import '../data/api/api_exception.dart';
import '../data/repositories/field_repository.dart';

/// One queued field operation. Immutable facts only — evidence and verification
/// submissions — so a replay can never conflict with anything the server holds.
class OutboxOp {
  final String clientUuid;
  final String type; // 'verification' | 'evidence'
  final Map<String, dynamic> payload;
  final DateTime queuedAt;
  final String? lastError;

  const OutboxOp({
    required this.clientUuid,
    required this.type,
    required this.payload,
    required this.queuedAt,
    this.lastError,
  });

  Map<String, dynamic> toJson() => {
        'client_uuid': clientUuid,
        'type': type,
        'payload': payload,
        'queued_at': queuedAt.toIso8601String(),
        if (lastError != null) 'last_error': lastError,
      };

  factory OutboxOp.fromJson(Map<String, dynamic> json) => OutboxOp(
        clientUuid: '${json['client_uuid']}',
        type: '${json['type']}',
        payload: Map<String, dynamic>.from(json['payload'] ?? {}),
        queuedAt:
            DateTime.tryParse('${json['queued_at']}') ?? DateTime.now(),
        lastError: json['last_error'] == null ? null : '${json['last_error']}',
      );

  OutboxOp withError(String? error) => OutboxOp(
        clientUuid: clientUuid,
        type: type,
        payload: payload,
        queuedAt: queuedAt,
        lastError: error,
      );

  String get label => switch (type) {
        'verification' => 'Field verification',
        'evidence' => 'Site photo',
        _ => type,
      };
}

/// The real answer to "Pending Sync: N".
///
/// Every write the officer makes in the field goes through here. Online, it
/// flushes immediately and the count stays 0. Offline, the work is durable on
/// disk and replays when the connection returns — the server deduplicates on
/// `client_uuid`, so a replay is always safe.
class OutboxProvider extends ChangeNotifier {
  OutboxProvider(this._field);

  final FieldRepository _field;
  static const _key = 'outbox_ops_v1';

  static const _lastFlushKey = 'outbox_last_flush_at';

  List<OutboxOp> _ops = [];
  final List<OutboxOp> _rejected = [];
  bool _flushing = false;
  bool _online = true;
  DateTime? _lastFlushAt;

  List<OutboxOp> get ops => List.unmodifiable(_ops);
  int get pendingCount => _ops.length;
  bool get flushing => _flushing;
  bool get online => _online;
  bool get hasPending => _ops.isNotEmpty;

  /// When this device last *delivered* queued work to the server.
  ///
  /// Null means nothing has needed syncing since install — which is not the
  /// same as "never synced" and must not be rendered as a stale timestamp.
  DateTime? get lastFlushAt => _lastFlushAt;

  /// Ops the server permanently refused.
  ///
  /// These are not retried — the server will never accept them — but they are
  /// not thrown away either. An officer who recorded a verification is
  /// entitled to see that it was rejected and why, rather than watch the
  /// pending count reach zero and assume it landed.
  List<OutboxOp> get rejected => List.unmodifiable(_rejected);
  bool get hasRejected => _rejected.isNotEmpty;

  void acknowledgeRejected() {
    _rejected.clear();
    notifyListeners();
  }

  Future<void> init() async {
    await _load();
    final result = await Connectivity().checkConnectivity();
    _online = !result.contains(ConnectivityResult.none);
    Connectivity().onConnectivityChanged.listen((result) {
      final wasOffline = !_online;
      _online = !result.contains(ConnectivityResult.none);
      notifyListeners();
      if (wasOffline && _online) flush();
    });
    if (_online) await flush();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = prefs.getString(_lastFlushKey);
    if (stamp != null) _lastFlushAt = DateTime.tryParse(stamp);

    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _ops = list
          .whereType<Map>()
          .map((e) => OutboxOp.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      _ops = [];
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_ops.map((o) => o.toJson()).toList()));
    notifyListeners();
  }

  /// Submits a field verification, queueing it if the send fails.
  /// Returns true when it reached the server on this attempt.
  Future<bool> submitVerification({
    required String verificationId,
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
    final op = OutboxOp(
      clientUuid: DeviceId.newUuid(),
      type: 'verification',
      queuedAt: DateTime.now(),
      payload: {
        'verification_id': verificationId,
        'observed_status': observedStatus,
        'measured_value': measuredValue,
        'measured_unit': measuredUnit,
        'measure_method': measureMethod,
        'measure_accuracy_m': measureAccuracyM,
        'lat': lat,
        'lon': lon,
        'notes': notes,
        'evidence_ids': evidenceIds,
      },
    );
    return _attempt(op);
  }

  /// Queues a photo upload. The file stays on disk until it lands, so the
  /// officer can walk out of coverage mid-upload without losing the evidence.
  Future<bool> uploadEvidence({
    required String workCode,
    required String filePath,
    bool isMockLocation = false,
    double? claimedAccuracyM,
  }) async {
    final op = OutboxOp(
      clientUuid: DeviceId.newUuid(),
      type: 'evidence',
      queuedAt: DateTime.now(),
      payload: {
        'work_code': workCode,
        'file_path': filePath,
        'is_mock_location': isMockLocation,
        'claimed_accuracy_m': claimedAccuracyM,
      },
    );
    return _attempt(op);
  }

  Future<bool> _attempt(OutboxOp op) async {
    if (!_online) {
      _ops.add(op);
      await _persist();
      return false;
    }
    try {
      await _send(op);
      return true;
    } on ApiException catch (e) {
      // A rejection is permanent — queueing it would retry forever. Only
      // transport failures are worth keeping.
      if (!e.isNetwork) rethrow;
      _ops.add(op.withError(e.message));
      await _persist();
      return false;
    }
  }

  Future<void> _send(OutboxOp op) async {
    final p = op.payload;
    switch (op.type) {
      case 'verification':
        await _field.submit(
          verificationId: '${p['verification_id']}',
          clientUuid: op.clientUuid,
          observedStatus: '${p['observed_status']}',
          measuredValue: (p['measured_value'] as num?)?.toDouble(),
          measuredUnit: p['measured_unit'] as String?,
          measureMethod: p['measure_method'] as String?,
          measureAccuracyM: (p['measure_accuracy_m'] as num?)?.toDouble(),
          lat: (p['lat'] as num?)?.toDouble(),
          lon: (p['lon'] as num?)?.toDouble(),
          notes: p['notes'] as String?,
          evidenceIds: (p['evidence_ids'] as List?)?.map((e) => '$e').toList() ?? [],
        );
      case 'evidence':
        final file = File('${p['file_path']}');
        if (!file.existsSync()) return; // user cleared the cache; drop it
        await _field.uploadEvidence(
          workCode: '${p['work_code']}',
          photo: file,
          clientUuid: op.clientUuid,
          isMockLocation: p['is_mock_location'] == true,
          claimedAccuracyM: (p['claimed_accuracy_m'] as num?)?.toDouble(),
        );
      default:
        return;
    }
  }

  /// Drains the queue in order. Stops at the first transport failure so
  /// ordering is preserved; permanent rejections are dropped with their reason.
  Future<void> flush() async {
    if (_flushing || _ops.isEmpty || !_online) return;
    _flushing = true;
    notifyListeners();

    final remaining = <OutboxOp>[];
    var blocked = false;
    var delivered = 0;

    for (final op in _ops) {
      if (blocked) {
        remaining.add(op);
        continue;
      }
      try {
        await _send(op);
        delivered++;
      } on ApiException catch (e) {
        if (e.isNetwork) {
          blocked = true;
          remaining.add(op.withError(e.message));
        } else {
          // The server will never accept this op, so retrying forever is
          // pointless -- but discarding it silently is worse. The officer
          // recorded something and is entitled to know it did not land.
          _rejected.add(op.withError(e.message));
        }
      }
    }

    // Stamped only when something was actually delivered.
    //
    // Two ways this could lie if written carelessly: stamping after a flush
    // that ended still blocked, and stamping after a flush whose every op was
    // rejected. Both would leave an officer reading "synced 2 min ago" while
    // their evidence sat on the device or was refused outright.
    if (delivered > 0) {
      _lastFlushAt = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastFlushKey, _lastFlushAt!.toIso8601String());
    }

    _ops = remaining;
    _flushing = false;
    await _persist();
  }

  Future<void> discard(String clientUuid) async {
    _ops.removeWhere((o) => o.clientUuid == clientUuid);
    await _persist();
  }

  Future<void> clear() async {
    _ops = [];
    await _persist();
  }
}
