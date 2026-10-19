import 'package:flutter/foundation.dart';

/// Destino dos erros inesperados (ex.: Crashlytics).
abstract interface class ErrorReporter {
  Future<void> report(Object error, StackTrace? stackTrace, {bool fatal});
}

/// Implementação padrão: apenas registra no console em debug.
///
/// O app fornece HttpErrorReporter via Provider para encaminhar os erros ao
/// destino inicializado no APP-19. Esta implementação serve para uso isolado.
class DebugErrorReporter implements ErrorReporter {
  const DebugErrorReporter();

  @override
  Future<void> report(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
  }) async {
    if (kDebugMode) {
      debugPrint('[ErrorReporter] fatal=$fatal $error\n$stackTrace');
    }
  }
}
