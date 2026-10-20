import '../crash/error_reporter.dart' as http_errors;
import 'error_reporter.dart';

/// Conecta o contrato do cliente Dio ao mesmo destino das demais camadas.
class HttpErrorReporter implements http_errors.ErrorReporter {
  const HttpErrorReporter({required this.errorReporter});

  final ErrorReporter errorReporter;

  @override
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    try {
      await errorReporter.recordError(
        error,
        stackTrace ?? StackTrace.current,
        fatal: fatal,
      );
    } on Object {
      // Uma falha no destino não substitui o erro de domínio do cliente HTTP.
    }
  }
}
