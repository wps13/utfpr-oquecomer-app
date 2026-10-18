import 'package:flutter/foundation.dart';

/// Destino dos erros inesperados (ex.: Crashlytics).
abstract interface class ErrorReporter {
  Future<void> report(Object error, StackTrace? stackTrace, {bool fatal});
}

/// Implementação padrão: apenas registra no console em debug.
///
/// TODO(App-20): trocar por uma implementação com `firebase_crashlytics`
/// assim que o projeto Firebase (google-services.json /
/// GoogleService-Info.plist) estiver configurado.
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
