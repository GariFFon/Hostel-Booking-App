import 'dart:async';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'envelope.dart';
import 'token_store.dart';

/// Thin typed wrapper over Dio for the Hostel Booking REST API.
///
/// - Attaches the bearer token and, on 401, refreshes **once, single-flight** and retries the request. The backend treats a
///   replayed refresh token as theft and revokes the whole session family, so parallel refreshes must never happen.
/// - Maps every failure to [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required this.tokens, Dio? dio, Dio? bareDio, this.onSignedOut, this.onSessionUser})
    : _dio = dio ?? Dio(_options(baseUrl)),
      _bare = bareDio ?? Dio(_options(baseUrl)) {
    _dio.interceptors.add(_authInterceptor());
  }

  static BaseOptions _options(String baseUrl) => BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 12),
    sendTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: const {'Accept': 'application/json'},
    responseType: ResponseType.json,
  );

  final TokenStore tokens;

  /// Called when the refresh token is rejected: the session is gone and the UI must go to sign-in.
  final void Function()? onSignedOut;

  /// Called with the user JSON that every successful refresh returns, so the session can stay fresh.
  final void Function(Map<String, dynamic> user)? onSessionUser;

  final Dio _dio;
  final Dio _bare;
  Future<String?>? _refreshing;

  InterceptorsWrapper _authInterceptor() => InterceptorsWrapper(
    onRequest: (options, handler) async {
      if (options.extra['auth'] != false) {
        final t = await tokens.read();
        if (t != null) {
          options.headers['Authorization'] = 'Bearer ${t.access}';
          options.extra['usedAccess'] = t.access;
        }
      }
      handler.next(options);
    },
    onError: (err, handler) async {
      final opts = err.requestOptions;
      final unauthorised = err.response?.statusCode == 401;
      if (!unauthorised || opts.extra['auth'] == false || opts.extra['retried'] == true) {
        return handler.next(err);
      }
      try {
        final fresh = await _refresh(opts.extra['usedAccess'] as String?);
        if (fresh == null) return handler.next(err);
        opts.headers['Authorization'] = 'Bearer $fresh';
        opts.extra['retried'] = true;
        handler.resolve(await _dio.fetch<Object?>(opts));
      } on DioException catch (e) {
        handler.next(e);
      } catch (_) {
        // Not a transport problem (bad refresh payload, storage error): hand back the original 401 so the person is asked to sign
        // in again, instead of Dio wrapping this as "can't reach the server".
        handler.next(err);
      }
    },
  );

  /// Single-flight refresh. Returns the new access token, or null when the session is over.
  Future<String?> _refresh(String? usedAccess) async {
    final current = await tokens.read();
    if (current == null) return null;
    // Another request already rotated the tokens while this one was in flight: just use the new access token.
    if (usedAccess != null && current.access != usedAccess) return current.access;
    return _refreshing ??= _doRefresh(current.refresh).whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh(String refreshToken) async {
    try {
      final res = await _bare.post<Object?>('/auth/refresh', data: {'refreshToken': refreshToken});
      final data = asMap(Envelope.fromBody(res.data).data);
      final access = data['accessToken'] as String?;
      final refresh = data['refreshToken'] as String?;
      if (access == null || refresh == null) throw ApiException(code: 'UNKNOWN', message: 'Bad refresh response');
      await tokens.write(TokenPair(access: access, refresh: refresh)); // persist before anything else uses it
      final user = data['user'];
      if (user is Map<String, dynamic>) onSessionUser?.call(user);
      return access;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        await tokens.clear();
        onSignedOut?.call();
        return null;
      }
      rethrow; // offline or server trouble: keep the session, the caller sees a network error
    }
  }

  /// Forces a (single-flight) refresh, e.g. after the role changed. False when the session is over.
  Future<bool> refreshSession() async => (await _refresh(null)) != null;

  Future<Envelope> send(
    String method,
    String path, {
    Map<String, Object?>? query,
    Object? body,
    Map<String, String>? headers,
    bool auth = true,
    CancelToken? cancel,
  }) async {
    try {
      final res = await _dio.request<Object?>(
        path,
        data: body,
        queryParameters: _cleanQuery(query),
        cancelToken: cancel,
        options: Options(method: method, headers: headers, extra: {'auth': auth}),
      );
      return Envelope.fromBody(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<Envelope> get(String path, {Map<String, Object?>? query, bool auth = true, CancelToken? cancel}) =>
      send('GET', path, query: query, auth: auth, cancel: cancel);

  Future<Envelope> post(String path, {Object? body, Map<String, String>? headers, bool auth = true}) =>
      send('POST', path, body: body ?? const <String, Object?>{}, headers: headers, auth: auth);

  Future<Envelope> put(String path, {Object? body}) => send('PUT', path, body: body ?? const <String, Object?>{});

  Future<Envelope> patch(String path, {Object? body}) => send('PATCH', path, body: body ?? const <String, Object?>{});

  Future<Envelope> delete(String path) => send('DELETE', path);

  /// Direct multipart upload (Cloudinary). No auth header: the request is signed by the fields themselves.
  Future<Map<String, dynamic>> uploadForm(String url, Map<String, String> fields, MultipartFile file) async {
    try {
      final res = await _bare.post<Object?>(
        url,
        data: FormData.fromMap({...fields, 'file': file}),
        options: Options(headers: const {'Accept': 'application/json'}),
      );
      return asMap(res.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static Map<String, Object?>? _cleanQuery(Map<String, Object?>? q) {
    if (q == null) return null;
    final out = <String, Object?>{};
    q.forEach((k, v) {
      if (v == null) return;
      if (v is String && v.isEmpty) return;
      if (v is Iterable) {
        if (v.isNotEmpty) out[k] = v.join(',');
        return;
      }
      out[k] = v;
    });
    return out.isEmpty ? null : out;
  }
}

/// Parsing helpers so repositories stay one-liners.
extension ApiParsing on ApiClient {
  Future<T> getOne<T>(String path, T Function(JsonMap json) parse, {Map<String, Object?>? query, bool auth = true, CancelToken? cancel}) async =>
      parse(asMap((await get(path, query: query, auth: auth, cancel: cancel)).data));

  Future<List<T>> getList<T>(
    String path,
    T Function(JsonMap json) parse, {
    Map<String, Object?>? query,
    bool auth = true,
    CancelToken? cancel,
  }) async => asList((await get(path, query: query, auth: auth, cancel: cancel)).data).map(parse).toList();

  Future<Paged<T>> getPage<T>(
    String path,
    T Function(JsonMap json) parse, {
    Map<String, Object?>? query,
    bool auth = true,
    CancelToken? cancel,
  }) async {
    final e = await get(path, query: query, auth: auth, cancel: cancel);
    return Paged<T>(items: asList(e.data).map(parse).toList(), nextCursor: e.nextCursor, total: e.total);
  }

  Future<T> postOne<T>(String path, T Function(JsonMap json) parse, {Object? body, Map<String, String>? headers}) async =>
      parse(asMap((await post(path, body: body, headers: headers)).data));
}
