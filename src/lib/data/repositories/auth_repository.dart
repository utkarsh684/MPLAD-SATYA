import 'dart:io' show Platform;

import '../api/api_client.dart';
import '../models/json.dart';
import '../models/user.dart';

class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// The server answers 200 whether or not the number is registered — telling
  /// the caller which numbers exist would be free account enumeration.
  Future<OtpChallenge> requestOtp(String phone) async {
    final json = await _api.post('/auth/otp/request', body: {'phone': phone});
    return OtpChallenge.fromJson(asMap(json));
  }

  Future<TokenPair> verifyOtp({
    required String requestId,
    required String phone,
    required String otp,
    required String deviceId,
    String? fcmToken,
    String appVersion = '1.0.0',
  }) async {
    final json = await _api.post('/auth/otp/verify', body: {
      'request_id': requestId,
      'phone': phone,
      'otp': otp,
      'device': {
        'device_id': deviceId,
        'platform': Platform.isIOS ? 'ios' : 'android',
        if (fcmToken != null) 'fcm_token': fcmToken,
        'app_version': appVersion,
      },
    });
    final tokens = TokenPair.fromJson(asMap(json));
    await _api.tokens.save(
      access: tokens.accessToken,
      refresh: tokens.refreshToken,
    );
    return tokens;
  }

  Future<AppUser> me() async {
    final json = await _api.get('/auth/me');
    return AppUser.fromJson(asMap(json));
  }

  /// Revokes every session for this user server-side, then clears local tokens.
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _api.tokens.clear();
    }
  }
}
