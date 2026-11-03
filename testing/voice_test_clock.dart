import 'dart:async';
import 'dart:collection';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avança somente o relógio dos serviços, sem depender de frames da UI.
class VoiceTestClock {
  final _pumps = Queue<(Duration, Completer<void>)>();

  Future<void> pump([Duration elapsed = Duration.zero]) {
    final completion = Completer<void>();
    _pumps.add((elapsed, completion));
    return completion.future;
  }
}

void testWithVoiceClock(
  String description,
  Future<void> Function(VoiceTestClock clock) body,
) {
  test(description, () {
    fakeAsync((time) {
      final clock = VoiceTestClock();
      var finished = false;
      Object? failure;
      StackTrace? stack;
      unawaited(
        Future<void>.sync(() => body(clock)).then(
          (_) {
            finished = true;
          },
          onError: (Object error, StackTrace trace) {
            failure = error;
            stack = trace;
            finished = true;
          },
        ),
      );
      for (var turn = 0; turn < 1000 && !finished; turn++) {
        time.flushMicrotasks();
        if (clock._pumps.isNotEmpty) {
          final (elapsed, completion) = clock._pumps.removeFirst();
          time.elapse(elapsed);
          completion.complete();
        } else if (!finished) {
          throw StateError(
            'Teste aguardando um Future sem conclusão simulada.',
          );
        }
      }
      time.flushMicrotasks();
      if (failure != null) Error.throwWithStackTrace(failure!, stack!);
      expect(finished, isTrue, reason: 'O cenário deve terminar.');
      expect(
        time.pendingTimers.length,
        0,
        reason: 'O descarte deve cancelar timers.',
      );
    });
  });
}
