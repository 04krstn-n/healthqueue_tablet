/// Thrown for any failed API call — non-2xx HTTP response, network failure,
/// or a request timeout. Kept under the historical name `StaffApiException`
/// since that's what every provider/screen in this app already catches.
class StaffApiException implements Exception {
  final String message;
  final int? statusCode;

  /// True when the request never reached the server (DNS/connection/socket
  /// failure) or timed out, as opposed to the server responding with an
  /// error status.
  final bool isNetworkError;

  StaffApiException(
    this.message, {
    this.statusCode,
    this.isNetworkError = false,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;

  @override
  String toString() => message;
}

/// Backwards-compatible alias — some older code may reference `ApiException`.
typedef ApiException = StaffApiException;
