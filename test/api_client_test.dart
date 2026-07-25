import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drop/core/errors/exceptions.dart';
import 'package:drop/core/network/api_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scripted HTTP adapter — answers each request from [handler] without any
/// real network, and records every request it saw.
class _FakeAdapter implements HttpClientAdapter {
  final ResponseBody Function(RequestOptions options, int callCount) handler;
  final List<RequestOptions> seen = [];

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    return handler(options, seen.length);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Map<String, dynamic> body) =>
    ResponseBody.fromString(jsonEncode(body), status,
        headers: {'content-type': ['application/json']});

ApiClient _client(_FakeAdapter adapter, AuthTokenProvider tokenProvider) {
  final dio = Dio()..httpClientAdapter = adapter;
  return ApiClient(
    baseUrl: 'https://api.test',
    tokenProvider: tokenProvider,
    dio: dio,
  );
}

DioException _dioError(DioExceptionType type, {Response<dynamic>? response}) =>
    DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: type,
        response: response);

Response<dynamic> _errorResponse(int status, dynamic data) => Response(
    requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data);

void main() {
  group('ApiClient auth interceptor', () {
    test('attaches the Firebase ID token as a Bearer header', () async {
      final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
      final client = _client(
          adapter, ({bool forceRefresh = false}) async => 'token-abc');

      final data = await client.get('/health');

      expect(data, {'ok': true});
      expect(adapter.seen.single.headers['Authorization'], 'Bearer token-abc');
    });

    test('sends no Authorization header when signed out', () async {
      final adapter = _FakeAdapter((o, _) => _json(200, {'ok': true}));
      final client =
          _client(adapter, ({bool forceRefresh = false}) async => null);

      await client.get('/health');

      expect(adapter.seen.single.headers.containsKey('Authorization'), isFalse);
    });

    test('on 401: force-refreshes the token once and replays the request',
        () async {
      final refreshes = <bool>[];
      final adapter = _FakeAdapter((o, call) =>
          call == 1 ? _json(401, {'message': 'stale'}) : _json(200, {'ok': 1}));
      final client = _client(adapter, ({bool forceRefresh = false}) async {
        refreshes.add(forceRefresh);
        return forceRefresh ? 'fresh-token' : 'stale-token';
      });

      final data = await client.get('/chats');

      expect(data, {'ok': 1});
      expect(adapter.seen, hasLength(2));
      expect(adapter.seen.last.headers['Authorization'], 'Bearer fresh-token');
      expect(refreshes, [false, true]);
    });

    test('a second 401 surfaces as AuthException (no retry loop)', () async {
      final adapter =
          _FakeAdapter((o, _) => _json(401, {'message': 'revoked'}));
      final client = _client(
          adapter, ({bool forceRefresh = false}) async => 'dead-token');

      await expectLater(
          client.get('/chats'), throwsA(isA<AuthException>()));
      // Original + exactly one replay — never a third attempt.
      expect(adapter.seen, hasLength(2));
    });
  });

  group('mapDioException', () {
    test('timeouts and connection failures → ServerException', () {
      for (final t in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
        DioExceptionType.connectionError,
        DioExceptionType.unknown,
      ]) {
        expect(mapDioException(_dioError(t)), isA<ServerException>(),
            reason: '$t');
      }
    });

    test('403 → AuthException carrying the server message', () {
      final e = mapDioException(_dioError(DioExceptionType.badResponse,
          response: _errorResponse(403, {'message': 'Managers only.'})));
      expect(e, isA<AuthException>());
      expect((e as AuthException).message, 'Managers only.');
    });

    test('409 → ConflictException (benign refresh notice)', () {
      final e = mapDioException(_dioError(DioExceptionType.badResponse,
          response: _errorResponse(409, {'message': 'Already closed.'})));
      expect(e, isA<ConflictException>());
    });

    test('500 with a Nest validation list uses the first message', () {
      final e = mapDioException(_dioError(DioExceptionType.badResponse,
          response: _errorResponse(500, {
            'message': ['subject must not be empty', 'other'],
          })));
      expect((e as ServerException).message, 'subject must not be empty');
    });

    test('unreadable error body falls back to a friendly generic', () {
      final e = mapDioException(_dioError(DioExceptionType.badResponse,
          response: _errorResponse(502, '<html>Bad gateway</html>')));
      expect((e as ServerException).message, contains('502'));
    });
  });
}
