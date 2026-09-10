import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// A place resolved from OpenStreetMap's Nominatim service.
class GeoPlace {
  const GeoPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.type,
    this.boundingBox,
  });

  final String displayName;
  final double lat;
  final double lon;
  final String? type;

  /// [south, north, west, east]
  final List<double>? boundingBox;

  /// The long Nominatim name is unusable in a list row; take the leading parts.
  String get shortName {
    final parts = displayName.split(',').map((e) => e.trim()).toList();
    return parts.take(2).join(', ');
  }

  String get context {
    final parts = displayName.split(',').map((e) => e.trim()).toList();
    return parts.length <= 2 ? '' : parts.sublist(2).join(', ');
  }
}

/// Free-text place search and reverse geocoding via Nominatim.
///
/// Nominatim's usage policy requires an identifying User-Agent and caps callers
/// at one request per second; both are enforced here rather than left to the
/// caller. Results are cached for the session so re-searching a place the
/// officer already looked up costs nothing.
///
/// This is the only integration in the app that talks to a third party
/// directly instead of through our own backend, because it carries no MPLADS
/// data — only the text the officer typed.
class GeocodingService {
  GeocodingService._();
  static final instance = GeocodingService._();

  static const _base = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'MPLAD-SATYA/1.0 (SIH26102; MoSPI works verification)';

  /// Nominatim asks for no more than one request per second.
  static const _minInterval = Duration(milliseconds: 1100);

  final _http = http.Client();
  final Map<String, List<GeoPlace>> _cache = {};
  DateTime _lastCall = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _throttle() async {
    final since = DateTime.now().difference(_lastCall);
    if (since < _minInterval) await Future.delayed(_minInterval - since);
    _lastCall = DateTime.now();
  }

  /// Searches for a place, biased to India.
  ///
  /// Returns an empty list on any failure — a geocoder being unreachable must
  /// degrade the search box, never break the screen that hosts it.
  Future<List<GeoPlace>> search(String query, {int limit = 6}) async {
    final q = query.trim();
    if (q.length < 3) return const [];
    if (_cache.containsKey(q)) return _cache[q]!;

    await _throttle();
    final uri = Uri.parse('$_base/search').replace(queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'limit': '$limit',
      'countrycodes': 'in',
      'addressdetails': '0',
    });

    try {
      final response = await _http
          .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) return const [];

      final places = <GeoPlace>[];
      for (final item in decoded.whereType<Map>()) {
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null) continue;

        List<double>? bbox;
        final raw = item['boundingbox'];
        if (raw is List && raw.length == 4) {
          final parsed = raw.map((e) => double.tryParse('$e')).toList();
          if (!parsed.contains(null)) bbox = parsed.cast<double>();
        }

        places.add(GeoPlace(
          displayName: '${item['display_name'] ?? ''}',
          lat: lat,
          lon: lon,
          type: item['type'] == null ? null : '${item['type']}',
          boundingBox: bbox,
        ));
      }

      _cache[q] = places;
      return places;
    } catch (_) {
      return const [];
    }
  }

  /// Turns the officer's current fix into a human-readable place, so a field
  /// note can say "Kolar Road, Bhopal" rather than a pair of decimals.
  Future<String?> reverse(double lat, double lon) async {
    await _throttle();
    final uri = Uri.parse('$_base/reverse').replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'jsonv2',
      'zoom': '16',
    });

    try {
      final response = await _http
          .get(uri, headers: {'User-Agent': _userAgent, 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['display_name'] != null) {
        return '${decoded['display_name']}';
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
