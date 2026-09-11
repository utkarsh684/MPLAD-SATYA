/// Build-time configuration.
///
/// The endpoint is compiled in, never read at runtime, so a build cannot be
/// pointed somewhere unexpected after it ships. Select a target with Flutter's
/// own mechanism - see config/README.md:
///
///   flutter run --dart-define-from-file=config/render.json
///   flutter run --dart-define-from-file=config/local.json
///   flutter build apk --release --dart-define-from-file=config/render.json
///
/// The default is the deployed service, so a plain `flutter build apk` yields
/// a working demo build rather than one silently aimed at a loopback address
/// that exists only on a developer's machine. Override for local work.
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mplad-satya-hi8x.onrender.com',
  );

  /// True when this build talks to a server over plaintext HTTP.
  ///
  /// Only reachable in debug builds - the release network security config
  /// denies cleartext outright - but it is surfaced in Settings so nobody
  /// demonstrates over an unencrypted link without knowing it.
  static bool get isCleartext => apiBaseUrl.startsWith('http://');

  static const String apiPrefix = '/api/v1';

  /// Network call budget for normal calls. Rural 2G is the design target, so
  /// this is already generous.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Budget for the first call after launch.
  ///
  /// A Render instance that has been idle cold-starts in roughly 50 s, which
  /// would blow straight through [requestTimeout] and show a judge a failed
  /// app on the very first screen. The startup handshake against /readyz gets
  /// a longer budget on purpose: it wakes the service while the splash is up,
  /// so by the time an officer taps anything the instance is warm and normal
  /// calls can keep the tighter timeout.
  static const Duration coldStartTimeout = Duration(seconds: 75);

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
