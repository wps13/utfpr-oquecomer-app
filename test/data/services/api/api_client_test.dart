import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/api/api_client.dart';
import 'package:o_que_comer_app/data/services/crash/error_reporter.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<ResponseBody> Function(RequestOptions) _handler;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    last = options;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _SpyReporter implements ErrorReporter {
  final reported = <Object>[];
  bool unavailable = false;

  @override
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    if (unavailable) throw StateError('Destino indisponível');
    reported.add(error);
  }
}

ResponseBody _json(Object body, int status) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

void main() {
  late _SpyReporter reporter;

  ApiClient build(_FakeAdapter adapter, {Map<String, String>? headers}) =>
      ApiClient(
        baseUrl: 'https://catalogo.test',
        errorReporter: reporter,
        headers: headers ?? const {},
        enableLogs: false,
        httpClientAdapter: adapter,
      );

  setUp(() => reporter = _SpyReporter());

  test('parses a successful catalog response', () async {
    final adapter = _FakeAdapter(
      (_) async => _json({
        'items': ['arroz', 'feijão'],
      }, 200),
    );
    final data = await build(
      adapter,
      headers: {'x-test': '1'},
    ).get<Map<String, dynamic>>('/ingredients');

    expect(data['items'], ['arroz', 'feijão']);
    expect(adapter.last!.uri.toString(), 'https://catalogo.test/ingredients');
    expect(adapter.last!.headers['x-test'], '1');
  });

  test('maps connection error to NoConnectionFailure', () {
    final client = build(
      _FakeAdapter(
        (o) async => throw DioException.connectionError(
          requestOptions: o,
          reason: 'offline',
        ),
      ),
    );
    expect(client.get<dynamic>('/x'), throwsA(isA<NoConnectionFailure>()));
  });

  test('maps timeouts to TimeoutFailure', () {
    final client = build(
      _FakeAdapter(
        (o) async => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 1),
          requestOptions: o,
        ),
      ),
    );
    expect(client.get<dynamic>('/x'), throwsA(isA<TimeoutFailure>()));
  });

  test('maps 5xx to ServerFailure and 4xx to ClientFailure', () async {
    final server = build(_FakeAdapter((_) async => _json({}, 503)));
    await expectLater(
      server.get<dynamic>('/x'),
      throwsA(isA<ServerFailure>().having((f) => f.statusCode, 'status', 503)),
    );

    final client = build(_FakeAdapter((_) async => _json({}, 404)));
    await expectLater(
      client.get<dynamic>('/x'),
      throwsA(isA<ClientFailure>().having((f) => f.isNotFound, '404', true)),
    );
    expect(reporter.reported, isEmpty);
  });

  test('unexpected errors are reported', () async {
    final client = build(_FakeAdapter((_) async => throw StateError('boom')));
    await expectLater(
      client.get<dynamic>('/x'),
      throwsA(isA<UnexpectedFailure>()),
    );
    expect(reporter.reported, hasLength(1));
  });

  test('reporter failure does not replace the HTTP domain failure', () async {
    reporter.unavailable = true;
    final client = build(_FakeAdapter((_) async => throw StateError('boom')));
    await expectLater(
      client.get<dynamic>('/x'),
      throwsA(isA<UnexpectedFailure>()),
    );
  });
}
