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
