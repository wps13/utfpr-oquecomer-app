import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/errors/http_error_reporter.dart';

class RecordingReporter implements ErrorReporter {
  Object? error;
  StackTrace? stack;
  bool? fatal;
  bool shouldFail = false;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (shouldFail) throw StateError('Destino indisponível.');
    this.error = error;
    stack = stackTrace;
    this.fatal = fatal;
  }
}

void main() {
  test(
    'contrato HTTP encaminha erro e stack ao destino compartilhado',
    () async {
      final destination = RecordingReporter();
      final reporter = HttpErrorReporter(errorReporter: destination);
      final error = StateError('Falha de integração.');
      final stack = StackTrace.current;

      await reporter.report(error, stack);

      expect(destination.error, same(error));
      expect(destination.stack, same(stack));
      expect(destination.fatal, isFalse);
    },
  );

  test('preserva classificação fatal e fornece stack quando ausente', () async {
    final destination = RecordingReporter();
    await HttpErrorReporter(errorReporter: destination)
        .report(StateError('Falha.'), null, fatal: true);
    expect(destination.stack, isNotNull);
    expect(destination.fatal, isTrue);
  });

  test(
    'falha na telemetria não interrompe o retorno do cliente HTTP',
    () async {
      final destination = RecordingReporter()..shouldFail = true;
      await expectLater(
        HttpErrorReporter(errorReporter: destination)
            .report(StateError('Falha original.'), StackTrace.current),
        completes,
      );
    },
  );
}
