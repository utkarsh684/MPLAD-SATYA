import 'json.dart';
import 'money.dart';

/// Mirrors `WorkSummary` in server/app/schemas.py.
class WorkSummary {
  final String id;
  final String workCode;
  final String title;
  final String category;
  final String status;
  final String? ward;
  final String? districtName;
  final Money sanctionedAmount;
  final int? riskScore;

  /// Server band: `green` | `yellow` | `red`. Never invent a fourth.
  final String? riskBand;
  final String? bandLabel;
  final double? lat;
  final double? lon;
  final double? distanceM;
  final String? distanceLabel;

  const WorkSummary({
    required this.id,
    required this.workCode,
    required this.title,
    required this.category,
    required this.status,
    required this.sanctionedAmount,
    this.ward,
    this.districtName,
    this.riskScore,
    this.riskBand,
    this.bandLabel,
    this.lat,
    this.lon,
    this.distanceM,
    this.distanceLabel,
  });

  factory WorkSummary.fromJson(Map<String, dynamic> json) => WorkSummary(
        id: asString(json['id']),
        workCode: asString(json['work_code']),
        title: asString(json['title']),
        category: asString(json['category']),
        status: asString(json['status']),
        ward: asStringOrNull(json['ward']),
        districtName: asStringOrNull(json['district_name']),
        sanctionedAmount: Money.fromJson(json['sanctioned_amount']),
        riskScore: asIntOrNull(json['risk_score']),
        riskBand: asStringOrNull(json['risk_band']),
        bandLabel: asStringOrNull(json['band_label']),
        lat: asDoubleOrNull(json['lat']),
        lon: asDoubleOrNull(json['lon']),
        distanceM: asDoubleOrNull(json['distance_m']),
        distanceLabel: asStringOrNull(json['distance_label']),
      );

  bool get hasLocation => lat != null && lon != null;

  /// Ward and district, whichever are present.
  String get locationLabel =>
      [ward, districtName].where((e) => (e ?? '').isNotEmpty).join(', ');

  /// A work with no assessment yet is genuinely unscored — say so rather than
  /// rendering a misleading zero.
  bool get isScored => riskScore != null;
}

/// Mirrors `WorkDetail` — extends the summary with the sanction record.
class WorkDetail extends WorkSummary {
  final String? description;
  final String? implementingAgency;
  final double? sanctionedQty;
  final String? qtyUnit;
  final int physicalProgressPct;
  final DateTime? recommendationDate;
  final DateTime? sanctionDate;
  final DateTime? expectedCompletionDate;
  final DateTime? actualCompletionDate;
  final String? esakshiRef;

  const WorkDetail({
    required super.id,
    required super.workCode,
    required super.title,
    required super.category,
    required super.status,
    required super.sanctionedAmount,
    required this.physicalProgressPct,
    super.ward,
    super.districtName,
    super.riskScore,
    super.riskBand,
    super.bandLabel,
    super.lat,
    super.lon,
    super.distanceM,
    super.distanceLabel,
    this.description,
    this.implementingAgency,
    this.sanctionedQty,
    this.qtyUnit,
    this.recommendationDate,
    this.sanctionDate,
    this.expectedCompletionDate,
    this.actualCompletionDate,
    this.esakshiRef,
  });

  factory WorkDetail.fromJson(Map<String, dynamic> json) => WorkDetail(
        id: asString(json['id']),
        workCode: asString(json['work_code']),
        title: asString(json['title']),
        category: asString(json['category']),
        status: asString(json['status']),
        ward: asStringOrNull(json['ward']),
        districtName: asStringOrNull(json['district_name']),
        sanctionedAmount: Money.fromJson(json['sanctioned_amount']),
        riskScore: asIntOrNull(json['risk_score']),
        riskBand: asStringOrNull(json['risk_band']),
        bandLabel: asStringOrNull(json['band_label']),
        lat: asDoubleOrNull(json['lat']),
        lon: asDoubleOrNull(json['lon']),
        distanceM: asDoubleOrNull(json['distance_m']),
        distanceLabel: asStringOrNull(json['distance_label']),
        description: asStringOrNull(json['description']),
        implementingAgency: asStringOrNull(json['implementing_agency']),
        sanctionedQty: asDoubleOrNull(json['sanctioned_qty']),
        qtyUnit: asStringOrNull(json['qty_unit']),
        physicalProgressPct: asInt(json['physical_progress_pct']),
        recommendationDate: asDate(json['recommendation_date']),
        sanctionDate: asDate(json['sanction_date']),
        expectedCompletionDate: asDate(json['expected_completion_date']),
        actualCompletionDate: asDate(json['actual_completion_date']),
        esakshiRef: asStringOrNull(json['esakshi_ref']),
      );

  String get sanctionedQtyLabel => sanctionedQty == null
      ? '—'
      : '${sanctionedQty!.toStringAsFixed(sanctionedQty! % 1 == 0 ? 0 : 1)} ${qtyUnit ?? ''}'
          .trim();
}

/// Mirrors `Page[T]` — cursor pagination.
class Paged<T> {
  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  const Paged({required this.items, this.nextCursor, this.hasMore = false});

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Paged(
        items: asMapList(json['items']).map(parse).toList(),
        nextCursor: asStringOrNull(json['next_cursor']),
        hasMore: asBool(json['has_more']),
      );
}
