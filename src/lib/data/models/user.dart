import 'json.dart';

/// Mirrors `UserOut`. The server sends a masked phone — the app never holds
/// the full number after login.
class AppUser {
  final String id;
  final String? name;
  final String role;
  final String phoneMasked;
  final String? districtId;
  final String? districtName;

  const AppUser({
    required this.id,
    required this.role,
    required this.phoneMasked,
    this.name,
    this.districtId,
    this.districtName,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: asString(json['id']),
        name: asStringOrNull(json['name']),
        role: asString(json['role']),
        phoneMasked: asString(json['phone_masked']),
        districtId: asStringOrNull(json['district_id']),
        districtName: asStringOrNull(json['district_name']),
      );

  String get displayName => (name ?? '').isNotEmpty ? name! : phoneMasked;

  String get roleLabel => switch (role) {
        'field_officer' => 'Field Officer',
        'district_officer' => 'District Officer',
        'mospi_admin' => 'MoSPI Administrator',
        'citizen' => 'Citizen',
        _ => role,
      };

  /// Only these roles may act on a fund release. Mirrors the server's RBAC —
  /// the client hides what it cannot do, the server still enforces it.
  bool get canDecide => role == 'district_officer' || role == 'mospi_admin';

  bool get canRecompute => role == 'mospi_admin';
}

/// Mirrors `TokenPair`.
class TokenPair {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
        accessToken: asString(json['access_token']),
        refreshToken: asString(json['refresh_token']),
        expiresIn: asInt(json['expires_in']),
      );
}

/// Mirrors `OtpRequestOut`. `debugCode` is present only when the server runs
/// with SMS_PROVIDER=console — production refuses to boot in that mode.
class OtpChallenge {
  final String requestId;
  final int expiresIn;
  final int resendAfter;
  final String? debugCode;

  const OtpChallenge({
    required this.requestId,
    required this.expiresIn,
    required this.resendAfter,
    this.debugCode,
  });

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        requestId: asString(json['request_id']),
        expiresIn: asInt(json['expires_in'], 300),
        resendAfter: asInt(json['resend_after'], 30),
        debugCode: asStringOrNull(json['debug_code']),
      );
}
