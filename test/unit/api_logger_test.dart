import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hostel_booking_app/core/network/api_logger.dart';

/// Answers every request with a canned response (or a transport failure), so the logger sees exactly what Dio would.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    last = options;
    return reply(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  late List<String> lines;

  setUp(() {
    lines = [];
    ApiLogger.sink = lines.add;
  });

  Dio dioWith(_Adapter a, {bool enabled = true}) {
    final d = Dio(BaseOptions(baseUrl: 'http://api.test/api/v1', validateStatus: (s) => s != null && s >= 200 && s < 300))..httpClientAdapter = a;
    d.interceptors.add(ApiLogger(enabled: enabled));
    return d;
  }

  test('logs request and the real response under one id, masks secrets, and keeps the body whole', () async {
    final a = _Adapter(
      (_) => _json(200, {
        'data': {'accessToken': 'secret-at', 'name': 'Asha', 'items': List.generate(40, (i) => 'row-$i')},
      }),
    );
    final res = await dioWith(a).post(
      '/auth/login',
      data: {'email': 'a@b.c', 'password': 'hunter2'},
      options: Options(headers: {'Authorization': 'Bearer abc'}),
    );
    final all = lines.join('\n');

    expect((((res.data as Map)['data']) as Map)['name'], 'Asha'); // the caller still gets the untouched response
    expect(all, contains('POST /api/v1/auth/login'));
    expect(all, contains('http://api.test/api/v1/auth/login'));
    expect(all, contains('a@b.c'));
    expect(all, contains('row-39')); // not truncated
    expect(all, isNot(contains('hunter2')));
    expect(all, isNot(contains('secret-at')));
    expect(all, isNot(contains('Bearer abc')));
    expect(all, contains('SUCCESS   200'));
    final id = a.last!.headers['x-request-id'] as String;
    expect(RegExp(RegExp.escape(id)).allMatches(all).length, greaterThanOrEqualTo(2)); // the full id is on both the request and the response block
  });

  test('shows the backend error body for a failed response', () async {
    final a = _Adapter(
      (_) => _json(422, {
        'error': {
          'code': 'VALIDATION_FAILED',
          'message': 'bad',
          'details': [
            {'path': 'email'},
          ],
        },
      }),
    );
    await expectLater(dioWith(a).post('/auth/register', data: {'email': 'x'}), throwsA(isA<DioException>()));
    final all = lines.join('\n');
    expect(all, contains('FAILED   422'));
    expect(all, contains('VALIDATION_FAILED'));
    expect(all, contains('"path": "email"'));
  });

  test('logs a network failure with its type', () async {
    final a = _Adapter((o) => throw DioException.connectionError(requestOptions: o, reason: 'no route to host'));
    await expectLater(dioWith(a).get('/hostels'), throwsA(isA<DioException>()));
    expect(lines.join('\n'), contains('NETWORK FAILURE'));
  });

  test('describes multipart uploads without dumping the file', () async {
    final a = _Adapter((_) => _json(200, {'ok': true}));
    final form = FormData.fromMap({
      'api_key': 'k',
      'folder': 'hostels',
      'file': MultipartFile.fromBytes([1, 2, 3], filename: 'a.jpg'),
    });
    await dioWith(a).post('/upload', data: form);
    final all = lines.join('\n');
    expect(all, contains('a.jpg'));
    expect(all, contains('3 bytes'));
    expect(all, isNot(contains('"k"')));
  });

  test('disabled: prints nothing and adds no header', () async {
    final a = _Adapter((_) => _json(200, {'ok': true}));
    await dioWith(a, enabled: false).get('/x');
    expect(lines, isEmpty);
    expect(a.last!.headers.containsKey('x-request-id'), isFalse);
  });
}
