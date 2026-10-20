import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

class CrashlyticsErrorReporter implements ErrorReporter {
  CrashlyticsErrorReporter({
    required this.crashlytics,
    this.isReleaseMode = kReleaseMode,
  });

  final FirebaseCrashlytics crashlytics;
  final bool isReleaseMode;

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    if (!isReleaseMode) return;
    try {
      await crashlytics.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: fatal,
        printDetails: false,
      );
    } on Object {
      // Uma falha na telemetria não pode interromper o fluxo do aplicativo
      // nem gerar outro erro no handler global e entrar em recursão.
    }
  }
}
