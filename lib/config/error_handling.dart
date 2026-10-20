import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/services/errors/error_reporter.dart';

/// Instale uma única vez, no mesmo isolate/Zone de runApp e do binding.
void installErrorHandlers({
  required ErrorReporter errorReporter,
  FlutterExceptionHandler? presentError,
}) {
  final present = presentError ?? FlutterError.presentError;

  FlutterError.onError = (details) {
    present(details);
    unawaited(
      errorReporter.recordError(
        details.exception,
        details.stack ?? StackTrace.current,
        reason: 'Erro não tratado pelo framework Flutter',
        fatal: true,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    present(FlutterErrorDetails(exception: error, stack: stackTrace));
    unawaited(
      errorReporter.recordError(
        error,
        stackTrace,
        reason: 'Erro assíncrono não tratado no isolate principal',
        fatal: true,
      ),
    );
    return true;
  };
}
