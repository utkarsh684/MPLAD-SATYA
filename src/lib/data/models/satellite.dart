import 'json.dart';
import 'money.dart';

/// Mirrors `SatelliteResultOut`.
///
/// The detectability fields are the honest part of this feature: a ward road or
/// a water kiosk is genuinely below Cartosat's resolving power, so the result
/// is `inconclusive` by design and contributes zero points. The UI shows the
/// arithmetic rather than hiding it behind a confidence number.
class SatelliteResult {
  final String status;
  final double confidence;
  final String method;
  final double resolutionM;
  final String reason;
  final double? brightnessIndex;

  /// True only when two scenes from different dates were compared. A single
  /// pass cannot evidence that construction happened.
  final bool isTemporalComparison;
  final DateTime? observedAt;
  final String? captureDate;

  /// Which server-side adapter produced this — `bhuvan` (live ISRO WMS) or
  /// `fixture` (offline). Present on a fresh observation.
  final String? adapter;

  /// Provider recorded on the stored observation, e.g. `bhuvan_cartosat_live`.
  final String? provider;

  // Detectability arithmetic. Only a fresh observation carries these; stored
  // history rows do not, so they are nullable rather than defaulted to zero —
  // a zero here would read as "nothing is detectable", which is a real claim.
  final double? minDetectableM;
  final double? targetDimensionM;
  final double? detectabilityRatio;

  const SatelliteResult({
    required this.status,
    required this.confidence,
    required this.method,
    required this.resolutionM,
    required this.reason,
    this.brightnessIndex,
    this.isTemporalComparison = false,
    this.observedAt,
    this.captureDate,
    this.adapter,
    this.provider,
    this.minDetectableM,
    this.targetDimensionM,
    this.detectabilityRatio,
  });

  factory SatelliteResult.fromJson(Map<String, dynamic> json) => SatelliteResult(
        status: asString(json['status']),
        confidence: asDouble(json['confidence']),
        method: asString(json['method']),
        resolutionM: asDouble(json['resolution_m']),
        reason: asString(json['reason']),
        brightnessIndex: asDoubleOrNull(json['brightness_index']),
        isTemporalComparison: asBool(json['is_temporal_comparison']),
        observedAt: asDate(json['created_at']),
        captureDate: asStringOrNull(json['capture_date']),
        adapter: asStringOrNull(json['adapter']),
        provider: asStringOrNull(json['provider']),
        minDetectableM: asDoubleOrNull(json['min_detectable_m']),
        targetDimensionM: asDoubleOrNull(json['target_dimension_m']),
        detectabilityRatio: asDoubleOrNull(json['detectability_ratio']),
      );

  /// True when the reading came from ISRO Bhuvan over the network rather than
  /// the offline fixture adapter. Surfaced in the UI so a judge always knows
  /// which one produced the number on screen.
  bool get isLive =>
      adapter == 'bhuvan' ||
      (provider ?? '').contains('bhuvan') ||
      method.contains('bhuvan');

  String get sourceLabel =>
      isLive ? 'ISRO Bhuvan (live)' : 'Offline fixture adapter';

  /// Plain-language headline. Deliberately says what the sensor could see,
  /// never what the sensor "proves" about the work.
  String get plainVerdict => switch (status) {
        'match' => 'Consistent with the reported work',
        'mismatch' => 'Does not match the reported work',
        'inconclusive' => isTemporalComparison
            ? 'Imagery could not decide either way'
            : 'Cannot confirm from a single image',
        'unavailable' => 'No imagery available',
        _ => status,
      };

  /// Detectability expressed for a human rather than as a ratio.
  String? get detectabilityLabel {
    final ratio = detectabilityRatio;
    if (ratio == null) return null;
    if (ratio >= 2.0) return 'HIGH';
    if (ratio >= 1.0) return 'MODERATE';
    return 'BELOW SENSOR LIMIT';
  }

  /// What this observation is incapable of establishing. The most important
  /// sentence on the satellite tab.
  String get limitation {
    if (status == 'unavailable') {
      return 'This is a service outage, not a finding about the work.';
    }
    if (!isTemporalComparison) {
      return 'A single-date image cannot show whether the work was carried '
          'out — an asset built years ago looks identical to a new one. '
          'Field verification remains the deciding evidence.';
    }
    return 'Satellite evidence supports field verification; it does not '
        'replace it.';
  }

  bool get hasDetectability =>
      minDetectableM != null && targetDimensionM != null;

  bool get isInconclusive => status == 'inconclusive';

  String get statusLabel => switch (status) {
        'match' => 'Consistent with reported progress',
        'mismatch' => 'Contradicts reported progress',
        'inconclusive' => 'Below sensor resolution',
        'unavailable' => 'No imagery available',
        _ => status,
      };
}

/// Mirrors `EsakshiRecordOut` — the official MoSPI works record.
class EsakshiRecord {
  final String? esakshiRef;
  final String workCode;
  final String title;
  final String category;
  final Money sanctionedAmount;
  final String? sanctionDate;
  final String status;
  final int physicalProgressPct;
  final String? implementingAgency;
  final Money totalReleased;
  final Money totalPending;
  final int installmentsCount;
  final String source;
  final bool found;

  const EsakshiRecord({
    required this.workCode,
    required this.title,
    required this.category,
    required this.sanctionedAmount,
    required this.status,
    required this.physicalProgressPct,
    required this.totalReleased,
    required this.totalPending,
    required this.installmentsCount,
    required this.source,
    required this.found,
    this.esakshiRef,
    this.sanctionDate,
    this.implementingAgency,
  });

  factory EsakshiRecord.fromJson(Map<String, dynamic> json) => EsakshiRecord(
        esakshiRef: asStringOrNull(json['esakshi_ref']),
        workCode: asString(json['work_code']),
        title: asString(json['title']),
        category: asString(json['category']),
        sanctionedAmount: Money.fromJson(json['sanctioned_amount_paise']),
        sanctionDate: asStringOrNull(json['sanction_date']),
        status: asString(json['status']),
        physicalProgressPct: asInt(json['physical_progress_pct']),
        implementingAgency: asStringOrNull(json['implementing_agency']),
        totalReleased: Money.fromJson(json['total_released_paise']),
        totalPending: Money.fromJson(json['total_pending_paise']),
        installmentsCount: asInt(json['installments_count']),
        source: asString(json['source'], 'esakshi'),
        found: asBool(json['found'], true),
      );
}

/// Mirrors `EsakshiVerifyOut` — our record cross-checked against the official one.
class EsakshiVerification {
  final bool matches;
  final bool amountMatch;
  final bool statusMatch;
  final bool agencyMatch;
  final List<String> discrepancies;

  const EsakshiVerification({
    required this.matches,
    required this.amountMatch,
    required this.statusMatch,
    required this.agencyMatch,
    required this.discrepancies,
  });

  factory EsakshiVerification.fromJson(Map<String, dynamic> json) =>
      EsakshiVerification(
        matches: asBool(json['matches']),
        amountMatch: asBool(json['amount_match']),
        statusMatch: asBool(json['status_match']),
        agencyMatch: asBool(json['agency_match']),
        discrepancies: asStringList(json['discrepancies']),
      );
}
