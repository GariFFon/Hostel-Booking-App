import 'package:dio/dio.dart';

/// Every failure the UI can see. Backend errors keep their machine-readable [code]; transport problems use
/// the synthetic codes `NETWORK`, `TIMEOUT`, `CANCELLED` and `UNKNOWN`.
class ApiException implements Exception {
  ApiException({required this.code, required this.message, this.status, this.details, this.requestId, this.retryAfter});

  final String code;
  final String message;
  final int? status;
  final Object? details;
  final String? requestId;
  final Duration? retryAfter;

  bool get isNetwork => code == 'NETWORK' || code == 'TIMEOUT';
  bool get isCancelled => code == 'CANCELLED';
  bool get isUnauthenticated => code == 'UNAUTHENTICATED';
  bool get isForbidden => code == 'FORBIDDEN';
  bool get isNotFound => code == 'NOT_FOUND';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isValidation => code == 'VALIDATION_FAILED';

  /// `details` as `{field path -> first message}` for VALIDATION_FAILED. Paths look like `guests.0.fullName`.
  Map<String, String> get fieldErrors {
    final d = details;
    if (d is! List) return const {};
    final out = <String, String>{};
    for (final item in d) {
      if (item is! Map) continue;
      final path = item['path'];
      final msg = item['message'];
      if (msg is! String) continue;
      final key = path is List ? path.join('.') : '$path';
      out.putIfAbsent(key, () => msg);
    }
    return out;
  }

  /// Something safe and readable to show a person, never a stack trace or an enum name.
  String get userMessage {
    switch (code) {
      case 'NETWORK':
        return "Can't reach the server. Check your connection and try again.";
      case 'TIMEOUT':
        return 'That took too long. Please try again.';
      case 'RATE_LIMITED':
        final s = retryAfter?.inSeconds;
        return s != null && s > 0 ? 'Too many attempts. Try again in ${_wait(s)}.' : 'Too many attempts. Try again in a moment.';
      case 'VALIDATION_FAILED':
        final first = fieldErrors.values.isEmpty ? null : fieldErrors.values.first;
        return first ?? 'Some details look wrong. Check the highlighted fields.';
      case 'UNAUTHENTICATED':
        return 'Please sign in again to continue.';
      case 'DEPENDENCY_UNAVAILABLE':
        return 'This is temporarily unavailable. Please try again shortly.';
      case 'UNKNOWN':
        return 'Something went wrong. Please try again.';
      default:
        return message.isEmpty ? 'Something went wrong. Please try again.' : message;
    }
  }

  static String _wait(int seconds) {
    if (seconds < 90) return '$seconds seconds';
    final m = (seconds / 60).ceil();
    return '$m minutes';
  }

  factory ApiException.fromDio(DioException e) {
    final res = e.response;
    final data = res?.data;
    if (data is Map && data['error'] is Map) {
      final err = data['error'] as Map;
      final details = err['details'];
      final retryHeader = int.tryParse(res?.headers.value('retry-after') ?? '');
      final retryBody = details is Map && details['retryAfterSeconds'] is num ? (details['retryAfterSeconds'] as num).toInt() : null;
      final retry = retryHeader ?? retryBody;
      return ApiException(
        code: (err['code'] as String?) ?? 'UNKNOWN',
        message: (err['message'] as String?) ?? '',
        status: res?.statusCode,
        details: details,
        requestId: err['requestId'] as String?,
        retryAfter: retry == null ? null : Duration(seconds: retry),
      );
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiException(code: 'TIMEOUT', message: 'Request timed out');
      case DioExceptionType.connectionError:
        return ApiException(code: 'NETWORK', message: 'No connection');
      case DioExceptionType.cancel:
        return ApiException(code: 'CANCELLED', message: 'Cancelled');
      case DioExceptionType.badCertificate:
        return ApiException(code: 'NETWORK', message: 'Secure connection failed');
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return ApiException(
          code: res == null ? 'NETWORK' : 'UNKNOWN',
          message: res == null ? 'No connection' : 'Unexpected response',
          status: res?.statusCode,
        );
    }
  }

  @override
  String toString() => 'ApiException($code, $status, $message)';
}

/// Turns anything thrown into text that is safe to show.
String errorText(Object error) => error is ApiException ? error.userMessage : 'Something went wrong. Please try again.';
