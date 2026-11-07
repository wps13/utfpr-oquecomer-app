import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/error_handling.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';

class FakeErrorReporter implements ErrorReporter {
  final List<({Object error, StackTrace stack, bool fatal})> records = [];

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    records.add((error: error, stack: stackTrace, fatal: fatal));
  }
}

void main() {
  late FlutterExceptionHandler? previousFlutterHandler;
  late ErrorCallback? previousPlatformHandler;
  late FakeErrorReporter reporter;
  late List<FlutterErrorDetails> presented;

  setUp(() {
    previousFlutterHandler = FlutterError.onError;
    previousPlatformHandler = PlatformDispatcher.instance.onError;
    reporter = FakeErrorReporter();
    presented = [];
    installErrorHandlers(errorReporter: reporter, presentError: presented.add);
  });

  tearDown(() {
    FlutterError.onError = previousFlutterHandler;
    PlatformDispatcher.instance.onError = previousPlatformHandler;
  });

  test('Flutter errors preserve the exception, stack and fatal flag', () {
    final error = StateError('Flutter failure');
    final stack = StackTrace.current;
    FlutterError.onError!(FlutterErrorDetails(exception: error, stack: stack));
    expect(presented, hasLength(1));
    expect(reporter.records.single.error, same(error));
    expect(reporter.records.single.stack, same(stack));
    expect(reporter.records.single.fatal, isTrue);
  });

  test('missing Flutter stack is replaced with a usable current stack', () {
    FlutterError.onError!(
      FlutterErrorDetails(exception: StateError('No stack')),
    );
    expect(reporter.records.single.stack.toString(), isNotEmpty);
  });

  test('unhandled async errors are reported and marked handled', () {
    final error = StateError('Async failure');
    final stack = StackTrace.current;
    expect(PlatformDispatcher.instance.onError!(error, stack), isTrue);
    expect(presented, hasLength(1));
    expect(reporter.records.single.error, same(error));
    expect(reporter.records.single.stack, same(stack));
    expect(reporter.records.single.fatal, isTrue);
  });
}
