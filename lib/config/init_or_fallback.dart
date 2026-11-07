import 'package:flutter/foundation.dart';

/// Tempo máximo de espera por etapa; a splash nativa cobre esse intervalo.
const initTimeout = Duration(seconds: 3);

/// Se a inicialização falhar ou demorar mais que [timeout], o app segue com
/// [fallback] em vez de ficar preso na splash.
Future<T> initOrFallback<T>(
  Future<T> Function() init,
  T Function() fallback, {
  void Function(Object error, StackTrace stack)? onError,
  Duration timeout = initTimeout,
}) async {
  try {
    return await init().timeout(timeout);
  } on Object catch (error, stack) {
    debugPrint('[init] falhou, usando fallback: $error');
    onError?.call(error, stack);
    return fallback();
  }
}
