import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/init_or_fallback.dart';

void main() {
  test('returns the init result when it succeeds', () async {
    final result = await initOrFallback(() async => 'real', () => 'fallback');

    expect(result, 'real');
  });

  test('uses the fallback and reports when init throws', () async {
    Object? reported;

    final result = await initOrFallback(
      () async => throw StateError('hive quebrou'),
      () => 'fallback',
      onError: (error, _) => reported = error,
    );

    expect(result, 'fallback');
    expect(reported, isA<StateError>());
  });

  test('uses the fallback when init takes longer than the timeout', () async {
    Object? reported;

    final result = await initOrFallback(
      () => Completer<String>().future,
      () => 'fallback',
      onError: (error, _) => reported = error,
      timeout: const Duration(milliseconds: 50),
    );

    expect(result, 'fallback');
    expect(reported, isA<TimeoutException>());
  });

  test('does not call fallback or onError on success', () async {
    var fallbackCalls = 0;
    var errors = 0;

    await initOrFallback(() async => 1, () {
      fallbackCalls++;
      return 0;
    }, onError: (_, _) => errors++);

    expect(fallbackCalls, 0);
    expect(errors, 0);
  });

  test('timeout is at most 3 seconds', () {
    expect(initTimeout, lessThanOrEqualTo(const Duration(seconds: 3)));
  });
}
