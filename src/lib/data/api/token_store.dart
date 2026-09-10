import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT pair across app restarts.
///
/// ponytail: SharedPreferences, not the Android keystore. On a rooted device
/// the refresh token is readable. Upgrade to flutter_secure_storage before a
/// real MoSPI rollout; access tokens are short-lived so the demo risk is low.
class TokenStore {
  static const _accessKey = 'auth_access_token';
  static const _refreshKey = 'auth_refresh_token';

  String? _access;
  String? _refresh;
  bool _loaded = false;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => (_refresh ?? '').isNotEmpty;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_accessKey);
    _refresh = prefs.getString(_refreshKey);
    _loaded = true;
  }

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}
