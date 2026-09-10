import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A stable per-install identifier, used for device registration and as the
/// namespace for offline operation ids.
///
/// Deliberately a random UUID rather than a hardware id: no IMEI, no ANDROID_ID,
/// nothing that identifies the person holding the phone. It dies with the install.
class DeviceId {
  static const _key = 'device_install_id';
  static String? _cached;

  static Future<String> get() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_key);
    if (id == null || id.isEmpty) {
      id = newUuid();
      await prefs.setString(_key, id);
    }
    _cached = id;
    return id;
  }

  /// RFC 4122 v4, from the platform CSPRNG.
  static String newUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
