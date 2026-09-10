/// Build-time configuration.
///
/// Override at build time, never in source:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
///   flutter build apk --dart-define=API_BASE_URL=https://mplad-satya.onrender.com
///
/// The default targets the Android emulator loopback (10.0.2.2 is the host
/// machine as seen from the emulator). A physical phone on the demo hotspot
/// needs the laptop's LAN IP passed in explicitly.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String apiPrefix = '/api/v1';

  /// Network call budget. Rural 2G is the design target, so this is generous.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// How close a field officer must be to a work site for the capture to count
  /// as on-site. Mirrors the server's own geo tolerance.
  static const double onSiteRadiusMetres = 100;

  static Uri uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse(apiBaseUrl);
    final normalised = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path}$apiPrefix$normalised',
      queryParameters: query?.map((k, v) => MapEntry(k, '$v')),
    );
  }

  /// Root-level (un-prefixed) endpoints such as /readyz and /media.
  static Uri rootUri(String path) {
    final base = Uri.parse(apiBaseUrl);
    final normalised = path.startsWith('/') ? path : '/$path';
    return base.replace(path: '${base.path}$normalised');
  }
}
