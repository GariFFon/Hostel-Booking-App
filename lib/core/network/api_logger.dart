import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Central API debug logger: ONE Dio interceptor that logs every API call in the same shape.
///
/// - request: id, time, method, base URL, endpoint, full URL, headers, query, full body (JSON, form fields, file parts)
/// - response: id, time, status + text, headers, full body, duration, size
/// - failure: the real backend error body, or the transport error (timeout, no connection, cancelled, bad certificate)
///
/// Each response is matched to its request by an id that is also sent as `x-request-id`, so the backend log for the same call
/// carries the same id even when many requests run at once. Debug builds only: release builds and `flutter test` print nothing
/// and add nothing to requests. Secrets are masked; everything else is printed whole, never truncated.
class ApiLogger extends Interceptor {
  ApiLogger({bool? enabled, this.logRequests = true, this.logResponses = true}) : enabled = enabled ?? (kDebugMode && !_isFlutterTest);

  /// Install it twice around the auth interceptor: `ApiLogger(logResponses: false)` LAST (so the request shows the final
  /// Authorization header) and `ApiLogger(logRequests: false)` FIRST (so a 401 that the auth interceptor then retries is still logged).
  final bool enabled;
  final bool logRequests;
  final bool logResponses;

  static bool get _isFlutterTest => !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';

  static const _idKey = '_apiLogId';
  static const _startKey = '_apiLogStart';
  static const _mask = '[MASKED]';
  static final _sensitive = RegExp(
    r'(password|passwd|pwd|secret|token|authorization|api[-_]?key|apikey|cookie|credential|signature|cvv|^otp$)',
    caseSensitive: false,
  );
  static final _rand = Random.secure();
  static const _enc = JsonEncoder.withIndent('  ');

  // ANSI colours, understood by the VS Code Debug Console: orange = request, green = success, red = failure.
  static const _orange = '\x1b[38;5;208m';
  static const _green = '\x1b[32m';
  static const _red = '\x1b[31m';
  static const _reset = '\x1b[0m';

  static String _newId() {
    String hex(int n) => List.generate(n, (_) => _rand.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-${hex(4)}-${hex(12)}';
  }

  /// Deep copy with every sensitive field masked.
  static Object? maskDeep(Object? v, [int depth = 0]) {
    if (depth > 20) return v;
    if (v is Map) return {for (final e in v.entries) '${e.key}': _sensitive.hasMatch('${e.key}') ? _mask : maskDeep(e.value, depth + 1)};
    if (v is List) return v.map((e) => maskDeep(e, depth + 1)).toList();
    return v;
  }

  static Map<String, Object?> _maskHeaders(Map<String, dynamic> h) => {
    for (final e in h.entries) e.key: _sensitive.hasMatch(e.key) ? _mask : (e.value is List ? (e.value as List).join(', ') : e.value),
  };

  static Object? _describeBody(Object? data) {
    if (data == null) return '(none)';
    if (data is FormData) {
      return {
        'multipart/form-data fields': {for (final f in data.fields) f.key: _sensitive.hasMatch(f.key) ? _mask : f.value},
        'files': [
          for (final f in data.files) '${f.key}: ${f.value.filename ?? 'file'} · ${f.value.contentType ?? 'unknown type'} · ${f.value.length} bytes',
        ],
      };
    }
    if (data is Stream || data is Uint8List) return '[binary body]';
    return maskDeep(data);
  }

  static String _pretty(Object? v) {
    if (v is String) {
      // Dio hands back JSON as a string when the server sent a non-JSON content type: still show it structured when it parses.
      final t = v.trimLeft();
      if (t.startsWith('{') || t.startsWith('[')) {
        try {
          return _enc.convert(maskDeep(jsonDecode(v)));
        } catch (_) {}
      }
      return v.isEmpty ? '(empty)' : v;
    }
    try {
      return _enc.convert(maskDeep(v));
    } catch (_) {
      return '$v';
    }
  }

  /// Where finished blocks go. `developer.log` reaches the VS Code Debug Console as ONE clean message (no `I/flutter (pid):`
  /// prefix on every line, which Android's logcat adds to anything printed with print/debugPrint). Tests replace it.
  @visibleForTesting
  static void Function(String block) sink = (block) => developer.log(block, name: 'API');

  static const _labelWidth = 14;

  static bool _isScalar(Object? v) => v == null || v is num || v is bool || (v is String && !v.contains('\n'));

  /// Rows for one section. Short values sit on the row (`Method      GET`); maps become aligned `key  value` rows;
  /// everything else (JSON bodies, stack traces) is pretty-printed underneath, indented.
  static List<String> _rows(String label, Object? value) {
    if (_isScalar(value)) return ['${label.padRight(_labelWidth)}$value'];
    if (value is Map && value.values.every((v) => _isScalar(v) || v is List && v.every(_isScalar))) {
      final width = value.keys.fold<int>(0, (w, k) => max(w, '$k'.length));
      return [label, for (final e in value.entries) '  ${'${e.key}'.padRight(width)}  ${e.value is List ? (e.value as List).join(', ') : e.value}'];
    }
    return [label, ..._pretty(value).split('\n').map((l) => '  $l')];
  }

  /// One block per call, drawn as a box so it can be told apart from other console output at a glance.
  static void _print(String color, String title, Map<String, Object?> sections) {
    final b = StringBuffer('$color┌─ $title$_reset\n');
    var first = true;
    sections.forEach((k, v) {
      // A blank rail line before the larger sections keeps headers, query and body from running together.
      final rows = _rows(k, v);
      if (!first && rows.length > 1) b.write('$color│$_reset\n');
      first = false;
      for (final r in rows) {
        b.write('$color│$_reset $r\n');
      }
    });
    b.write('$color└${'─' * 70}$_reset');
    sink(b.toString());
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled && logRequests) {
      // A retried request (token refresh) re-enters here carrying the id of the first attempt: give it a fresh one.
      final previous = options.extra[_idKey] as String?;
      final sent = options.headers['x-request-id'] ?? options.headers['X-Request-Id'];
      final id = (sent == null || sent == previous) ? _newId() : '$sent';
      options.headers['x-request-id'] = id;
      options.extra[_idKey] = id;
      options.extra[_startKey] = DateTime.now().microsecondsSinceEpoch;
      _print(_orange, 'API ▶ REQUEST   ${options.method} ${options.uri.path}   #${id.substring(0, 8)}', {
        'Request ID': id,
        'Started at': DateTime.now().toUtc().toIso8601String(),
        'Method': options.method,
        'Base URL': options.baseUrl.isEmpty ? '${options.uri.scheme}://${options.uri.authority}' : options.baseUrl,
        'Endpoint': options.path,
        'Full URL': options.uri.toString(),
        'Headers': _maskHeaders(options.headers),
        'Query params': options.queryParameters.isEmpty ? '(none)' : maskDeep(options.queryParameters),
        'Body': _describeBody(options.data),
      });
    }
    handler.next(options);
  }

  int _ms(RequestOptions o) {
    final s = o.extra[_startKey] as int?;
    return s == null ? 0 : ((DateTime.now().microsecondsSinceEpoch - s) / 1000).round();
  }

  static int _size(Response<dynamic> r) {
    final cl = int.tryParse(r.headers.value('content-length') ?? '');
    if (cl != null) return cl;
    final d = r.data;
    if (d == null) return 0;
    try {
      return utf8.encode(d is String ? d : jsonEncode(d)).length;
    } catch (_) {
      return 0;
    }
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (enabled && logResponses) {
      final id = response.requestOptions.extra[_idKey] ?? '-';
      final code = response.statusCode ?? 0;
      final ms = _ms(response.requestOptions);
      final ok = code >= 200 && code < 300;
      _print(
        ok ? _green : _red,
        'API ${ok ? '✔ SUCCESS' : '✖ FAILED'}   ${'$code ${response.statusMessage ?? ''}'.trim()}   ${response.requestOptions.method} ${response.requestOptions.uri.path}   #${'$id'.substring(0, min(8, '$id'.length))}   $ms ms',
        {
          'Request ID': id,
          'Responded at': DateTime.now().toUtc().toIso8601String(),
          'Status': '$code ${response.statusMessage ?? ''}'.trim(),
          'Duration': '$ms ms',
          'Size': '${_size(response)} bytes',
          'Headers': _maskHeaders(response.headers.map),
          'Body': response.data,
        },
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled && logResponses) {
      final o = err.requestOptions;
      final id = o.extra[_idKey] ?? '-';
      final res = err.response;
      final ms = _ms(o);
      if (res != null) {
        _print(
          _red,
          'API ✖ FAILED   ${'${res.statusCode} ${res.statusMessage ?? ''}'.trim()}   ${o.method} ${o.uri.path}   #${'$id'.substring(0, min(8, '$id'.length))}   $ms ms',
          {
            'Request ID': id,
            'Responded at': DateTime.now().toUtc().toIso8601String(),
            'Status': '${res.statusCode} ${res.statusMessage ?? ''}'.trim(),
            'Duration': '$ms ms',
            'Size': '${_size(res)} bytes',
            'Headers': _maskHeaders(res.headers.map),
            'Error body (from backend)': res.data,
          },
        );
      } else {
        final kind = switch (err.type) {
          DioExceptionType.connectionTimeout => 'TIMEOUT (connect)',
          DioExceptionType.sendTimeout => 'TIMEOUT (send)',
          DioExceptionType.receiveTimeout => 'TIMEOUT (receive)',
          DioExceptionType.connectionError => 'NETWORK FAILURE',
          DioExceptionType.cancel => 'CANCELLED',
          DioExceptionType.badCertificate => 'BAD CERTIFICATE',
          _ => 'EXCEPTION',
        };
        _print(_red, 'API ✖ $kind   ${o.method} ${o.uri.path}   #${'$id'.substring(0, min(8, '$id'.length))}   $ms ms', {
          'Request ID': id,
          'Failed at': DateTime.now().toUtc().toIso8601String(),
          'Full URL': o.uri.toString(),
          'Duration': '$ms ms',
          'Error type': err.type.name,
          'Message': err.message ?? '(none)',
          'Underlying': '${err.error}',
          'Stack trace': '${err.stackTrace}',
        });
      }
    }
    handler.next(err);
  }
}
