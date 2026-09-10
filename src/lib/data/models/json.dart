/// Defensive JSON readers.
///
/// The server contract promises non-null for required fields, but a version
/// skew between a deployed API and an installed APK must degrade to a blank
/// field, never a red screen in front of a judge.
int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

int? asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

double? asDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String asString(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

String? asStringOrNull(dynamic v) => v == null ? null : '$v';

bool asBool(dynamic v, [bool fallback = false]) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  return fallback;
}

/// The API emits ISO-8601 UTC with a trailing Z. Returns local time for display.
DateTime? asDate(dynamic v) {
  if (v == null) return null;
  final parsed = DateTime.tryParse('$v');
  return parsed?.toLocal();
}

List<String> asStringList(dynamic v) =>
    v is List ? v.map((e) => '$e').toList() : const [];

List<Map<String, dynamic>> asMapList(dynamic v) => v is List
    ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

Map<String, dynamic> asMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : const {};
