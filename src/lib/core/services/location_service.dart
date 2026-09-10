import 'package:geolocator/geolocator.dart';

/// Real device GPS. Every "you are N metres from the site" claim in the UI
/// comes from here — nothing about the officer's position is ever assumed.
class LocationService {
  LocationService._();
  static final instance = LocationService._();

  Position? _last;
  Position? get lastKnown => _last;

  /// Returns null when the user declines the permission or the service is off.
  /// Callers must render "location unavailable" rather than inventing a fix.
  Future<Position?> current({
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeLimit = const Duration(seconds: 15),
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    try {
      _last = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: timeLimit,
        ),
      );
      return _last;
    } catch (_) {
      // A timeout on a weak fix is normal in the field; fall back to the last
      // position the OS cached rather than blocking the officer.
      _last = await Geolocator.getLastKnownPosition();
      return _last;
    }
  }

  /// Metres between two WGS-84 points, via the geodesic used by the server.
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) =>
      Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

  /// Continuous stream for the walk-the-length measurement mode.
  Stream<Position> track({int distanceFilterM = 2}) => Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: distanceFilterM,
        ),
      );

  /// Android exposes whether a fix came from a mock provider. The server folds
  /// this into the GPS trust score, so it must be reported honestly.
  bool isMocked(Position? position) => position?.isMocked ?? false;
}
