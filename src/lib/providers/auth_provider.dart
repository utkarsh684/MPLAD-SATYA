import 'package:flutter/foundation.dart';

import '../core/services/device_id.dart';
import '../data/api/api_client.dart';
import '../data/api/api_exception.dart';
import '../data/models/user.dart';
import '../data/repositories/auth_repository.dart';

enum AuthStatus { restoring, signedOut, awaitingOtp, signedIn }

/// Real phone-OTP authentication against the backend.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, this._repo) {
    _api.onSessionExpired = _onSessionExpired;
  }

  final ApiClient _api;
  final AuthRepository _repo;

  AuthStatus _status = AuthStatus.restoring;
  AppUser? _user;
  OtpChallenge? _challenge;
  String? _phone;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  OtpChallenge? get challenge => _challenge;
  String? get phone => _phone;
  String? get error => _error;
  bool get busy => _busy;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  /// Only non-null when the server runs with SMS_PROVIDER=console. Production
  /// refuses to boot in that mode, so this can never leak from a real deploy.
  String? get debugOtp => _challenge?.debugCode;

  /// Restores a session from disk on cold start.
  Future<void> restore() async {
    await _api.init();
    if (!_api.tokens.hasSession) {
      _set(AuthStatus.signedOut);
      return;
    }
    try {
      _user = await _repo.me();
      _set(AuthStatus.signedIn);
    } on ApiException {
      await _api.tokens.clear();
      _set(AuthStatus.signedOut);
    }
  }

  Future<bool> requestOtp(String phone) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      _phone = phone.trim();
      _challenge = await _repo.requestOtp(_phone!);
      _set(AuthStatus.awaitingOtp);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> verifyOtp(String otp) async {
    final challenge = _challenge;
    final phone = _phone;
    if (challenge == null || phone == null) {
      _error = 'Request a code first.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.verifyOtp(
        requestId: challenge.requestId,
        phone: phone,
        otp: otp.trim(),
        deviceId: await DeviceId.get(),
      );
      _user = await _repo.me();
      _challenge = null;
      _set(AuthStatus.signedIn);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp() async {
    if (_phone != null) await requestOtp(_phone!);
  }

  void backToPhone() {
    _challenge = null;
    _error = null;
    _set(AuthStatus.signedOut);
  }

  Future<void> signOut() async {
    _busy = true;
    notifyListeners();
    try {
      await _repo.logout();
    } on ApiException {
      // Already unreachable or already revoked — local state still clears.
    } finally {
      _user = null;
      _challenge = null;
      _phone = null;
      _busy = false;
      _set(AuthStatus.signedOut);
    }
  }

  void _onSessionExpired() {
    _user = null;
    _challenge = null;
    _error = 'Your session expired. Please sign in again.';
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
