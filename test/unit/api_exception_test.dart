import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_exception.dart';

DioException _bad(int status, Object? data, {Map<String, List<String>>? headers}) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: req, statusCode: status, data: data, headers: Headers.fromMap(headers ?? {})),
  );
}

void main() {
  test('backend error envelope keeps its machine-readable code', () {
    final e = ApiException.fromDio(_bad(409, {
      'error': {
        'code': 'PRICE_CHANGED',
        'message': 'The price changed.',
        'requestId': 'req_1',
        'details': {'expectedTotalPaise': 100, 'totalPaise': 120},
      },
    }));
    expect(e.code, 'PRICE_CHANGED');
    expect(e.status, 409);
    expect(e.requestId, 'req_1');
    expect((e.details as Map)['totalPaise'], 120);
    expect(e.userMessage, 'The price changed.');
  });

  test('validation details become field -> first message', () {
    final e = ApiException.fromDio(_bad(422, {
      'error': {
        'code': 'VALIDATION_FAILED',
        'message': 'Invalid',
        'details': [
          {'path': ['guests', 0, 'fullName'], 'message': 'Too short'},
          {'path': ['guests', 0, 'fullName'], 'message': 'Second message ignored'},
          {'path': ['contactPhone'], 'message': 'Bad number'},
        ],
      },
    }));
    expect(e.isValidation, isTrue);
    expect(e.fieldErrors, {'guests.0.fullName': 'Too short', 'contactPhone': 'Bad number'});
    expect(e.userMessage, 'Too short');
  });

  test('rate limits say how long to wait', () {
    final e = ApiException.fromDio(_bad(429, {'error': {'code': 'RATE_LIMITED', 'message': 'x'}}, headers: {'retry-after': ['45']}));
    expect(e.isRateLimited, isTrue);
    expect(e.retryAfter, const Duration(seconds: 45));
    expect(e.userMessage, 'Too many attempts. Try again in 45 seconds.');
    expect(ApiException(code: 'RATE_LIMITED', message: '', retryAfter: const Duration(minutes: 10)).userMessage, contains('10 minutes'));
  });

  test('transport failures use synthetic codes and never leak internals', () {
    final req = RequestOptions(path: '/x');
    expect(ApiException.fromDio(DioException(requestOptions: req, type: DioExceptionType.connectionError)).isNetwork, isTrue);
    expect(ApiException.fromDio(DioException(requestOptions: req, type: DioExceptionType.receiveTimeout)).code, 'TIMEOUT');
    expect(ApiException.fromDio(DioException(requestOptions: req, type: DioExceptionType.cancel)).isCancelled, isTrue);
    final html = ApiException.fromDio(_bad(502, '<html>Bad gateway</html>'));
    expect(html.code, 'UNKNOWN');
    expect(html.userMessage, 'Something went wrong. Please try again.');
  });

  test('errorText is safe for any thrown object', () {
    expect(errorText(StateError('boom: secret stack')), 'Something went wrong. Please try again.');
    expect(errorText(ApiException(code: 'NETWORK', message: '')), contains('connection'));
  });
}
