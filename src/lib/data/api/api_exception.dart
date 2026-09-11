/// Every backend error arrives as {"error": {"code", "message", "details"}}.
/// This is the single type the UI catches; screens render [message] directly.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, dynamic> details;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  /// Connectivity failure rather than a server rejection — the UI offers
  /// "retry" for these and "contact admin" for the rest.
  bool get isNetwork => code == 'network_error' || code == 'timeout';

  /// Whether sending this again could plausibly succeed.
  ///
  /// The outbox discards anything permanent, because retrying a rejection
  /// forever is pointless — so getting this wrong in the other direction
  /// throws away an officer's field verification. A dependency outage is
  /// transient by definition: the server answers `503 DATABASE_UNAVAILABLE`
  /// when it cannot reach Postgres, and a queued submission must survive that
  /// and replay, exactly as it survives being out of coverage.
  ///
  /// 502 and 504 are included for the same reason — a proxy or gateway blip in
  /// front of the API says nothing about the validity of the submission.
  bool get isRetryable =>
      isNetwork ||
      statusCode == 502 ||
      statusCode == 503 ||
      statusCode == 504;

  /// True when the server was reachable but its backing service was not.
  bool get isDependencyOutage =>
      code == 'DATABASE_UNAVAILABLE' || statusCode == 503;

  bool get isUnauthorized => statusCode == 401;

  factory ApiException.network(Object cause) => ApiException(
        code: 'network_error',
        message: 'Cannot reach the server. Check your connection and try again.',
        details: {'cause': '$cause'},
      );

  factory ApiException.timeout() => const ApiException(
        code: 'timeout',
        message: 'The server took too long to respond. Try again.',
      );

  factory ApiException.fromResponse(int status, dynamic body) {
    if (body is Map && body['error'] is Map) {
      final err = body['error'] as Map;
      return ApiException(
        code: '${err['code'] ?? 'error'}',
        message: '${err['message'] ?? 'Request failed'}',
        statusCode: status,
        details: Map<String, dynamic>.from(err['detail'] ?? err['details'] ?? {}),
      );
    }
    // FastAPI validation errors and anything else that escaped the envelope.
    if (body is Map && body['detail'] != null) {
      return ApiException(
        code: 'http_$status',
        message: '${body['detail']}',
        statusCode: status,
      );
    }
    return ApiException(
      code: 'http_$status',
      message: 'Request failed ($status)',
      statusCode: status,
    );
  }

  @override
  String toString() => 'ApiException($code): $message';
}
