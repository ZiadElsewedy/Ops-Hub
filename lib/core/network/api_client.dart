import 'package:dio/dio.dart';
// ⚠️ TEMPORARY DEBUG IMPORT — remove with the 401 investigation (debugPrint).
import 'package:flutter/foundation.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/network/network_config.dart';
import 'package:drop/core/utils/app_logger.dart';

/// Resolves the caller's bearer token for the NestJS API. Returns null when no
/// one is signed in (the request then goes out unauthenticated and the server
/// rejects it — the client never invents credentials). [forceRefresh] bypasses
/// the cached Firebase ID token after a 401.
typedef AuthTokenProvider = Future<String?> Function({bool forceRefresh});

/// The single HTTP seam for the external NestJS API — the `core/media/`
/// pattern applied to HTTP: one place that owns the base URL, timeouts, the
/// Bearer token, and error translation, so datasources built on it stay as thin
/// as the Firestore ones.
///
/// - Every request carries the caller's **Firebase ID token** (Firebase stays
///   the identity provider; the API verifies the token with the Admin SDK).
/// - The token is fetched per request — the Firebase SDK caches it and
///   transparently refreshes it near expiry. A **401** response additionally
///   force-refreshes once and retries, covering revocation/clock-skew edges.
/// - Every failure surfaces as one of the existing `core/errors` exceptions
///   (`ServerException` / `AuthException` / `ConflictException`) with a
///   user-readable message — callers never see a [DioException].
///
/// Consumed by the chat feature's `ChatRemoteDataSource`.
class ApiClient {
  final Dio _dio;

  ApiClient({
    required String baseUrl,
    required AuthTokenProvider tokenProvider,
    Dio? dio,
  }) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = NetworkConfig.timeout
      ..sendTimeout = NetworkConfig.timeout
      ..receiveTimeout = NetworkConfig.timeout
      ..responseType = ResponseType.json;
    _dio.interceptors.add(_AuthInterceptor(_dio, tokenProvider));
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(
    String path, {
    Object? body,
    void Function(int sent, int total)? onSendProgress,
  }) =>
      _send(() => _dio.post<dynamic>(
            path,
            data: body,
            onSendProgress: onSendProgress,
          ));

  Future<dynamic> put(String path, {Object? body}) =>
      _send(() => _dio.put<dynamic>(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch<dynamic>(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete<dynamic>(path, data: body));

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      return (await request()).data;
    } on DioException catch (e) {
      // The mapped exception carries only a user-facing message; the real
      // cause (connection refused, host unreachable, wrong base URL, a 500
      // body, …) lives on the DioException and would otherwise vanish. Log it
      // so a failing request is diagnosable instead of a silent generic error.
      final method = e.requestOptions.method;
      final url = e.requestOptions.uri;
      final status = e.response?.statusCode;
      AppLog.warning(
        'network',
        '$method $url failed: type=${e.type.name} '
            'status=${status ?? '-'} error=${e.error ?? e.message} '
            'body=${_briefBody(e.response?.data)}',
      );
      throw mapDioException(e);
    }
  }

  /// A short, log-safe rendering of a response body (truncated).
  static String _briefBody(dynamic data) {
    if (data == null) return '-';
    final s = data.toString();
    return s.length > 300 ? '${s.substring(0, 300)}…' : s;
  }
}

/// Attaches the Bearer token to every request; on a **401** force-refreshes the
/// token once and replays the request. A second 401 falls through to normal
/// error mapping (the session is genuinely dead, not stale).
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final AuthTokenProvider _token;

  static const _kRetried = 'authRetried';

  _AuthInterceptor(this._dio, this._token);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // A 401 replay already carries the force-refreshed token — re-fetching
    // here would overwrite it with the stale cached one.
    if (options.extra[_kRetried] == true) {
      _debugLogOutgoing(options); // ⚠️ TEMPORARY DEBUG — remove after 401 probe.
      return handler.next(options);
    }
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    _debugLogOutgoing(options); // ⚠️ TEMPORARY DEBUG — remove after 401 probe.
    handler.next(options);
  }

  /// ⚠️ TEMPORARY DEBUG — logs the exact Authorization header and URL of every
  /// outgoing request so we can confirm the Bearer token is actually attached.
  /// Remove this method and its two call sites once the 401 is diagnosed.
  void _debugLogOutgoing(RequestOptions options) {
    debugPrint('➡️[NET-PROBE] Request URL: ${options.method} ${options.uri}');
    debugPrint(
        '➡️[NET-PROBE] Authorization Header: ${options.headers['Authorization']}');
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    // ⚠️ TEMPORARY DEBUG — every HTTP response status. Remove after 401 probe.
    debugPrint(
        '⬅️[NET-PROBE] Response ${response.statusCode} '
        '${response.requestOptions.method} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // ⚠️ TEMPORARY DEBUG — every networking exception. Remove after 401 probe.
    debugPrint(
        '❌[NET-PROBE] ${err.type.name} status=${err.response?.statusCode ?? '-'} '
        '${err.requestOptions.method} ${err.requestOptions.uri} '
        'error=${err.error ?? err.message}');
    final alreadyRetried = err.requestOptions.extra[_kRetried] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      return handler.next(err);
    }
    try {
      final fresh = await _token(forceRefresh: true);
      if (fresh == null || fresh.isEmpty) return handler.next(err);
      final options = err.requestOptions
        ..extra[_kRetried] = true
        ..headers['Authorization'] = 'Bearer $fresh';
      return handler.resolve(await _dio.fetch<dynamic>(options));
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    } catch (_) {
      return handler.next(err);
    }
  }
}

/// Translates a [DioException] into the app's exception vocabulary — the HTTP
/// twin of the `FirebaseException` catch in every Firestore datasource.
/// 401/403 → [AuthException] · 409 → [ConflictException] (benign, "it was just
/// refreshed") · everything else → [ServerException].
Exception mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return const ServerException(
          'The server took too long to respond. Please try again.');
    case DioExceptionType.connectionError:
      return const ServerException(
          'Could not reach the server. Check your connection.');
    case DioExceptionType.cancel:
      return const ServerException('The request was cancelled.');
    case DioExceptionType.badCertificate:
      return const ServerException('Secure connection failed.');
    case DioExceptionType.badResponse:
      final status = e.response?.statusCode ?? 0;
      final message = _serverMessage(e.response?.data);
      if (status == 401) {
        return const AuthException(
            'Your session has expired. Please sign in again.');
      }
      if (status == 403) {
        return AuthException(
            message ?? 'You are not allowed to do that.');
      }
      if (status == 409) {
        return ConflictException(
            message ?? 'This was just changed by someone else.');
      }
      return ServerException(
          message ?? 'Something went wrong (HTTP $status). Please try again.');
    case DioExceptionType.unknown:
      return const ServerException(
          'Something went wrong. Please check your connection and try again.');
  }
}

/// Pulls a human-readable message out of a NestJS error body. Nest's default
/// shape is `{statusCode, message, error}` where `message` is a string or — for
/// validation errors — a list of strings (first one wins).
String? _serverMessage(dynamic data) {
  if (data is! Map) return null;
  final message = data['message'];
  if (message is String && message.trim().isNotEmpty) return message.trim();
  if (message is List && message.isNotEmpty) {
    final first = message.first;
    if (first is String && first.trim().isNotEmpty) return first.trim();
  }
  return null;
}
