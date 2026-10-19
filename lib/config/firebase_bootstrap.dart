import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../data/services/errors/crashlytics_error_reporter.dart';
import '../data/services/errors/error_reporter.dart';
import '../firebase_options.dart';

/// A política nativa por build é reforçada antes de instalar os handlers Dart.
Future<ErrorReporter> initializeErrorReporting() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS)) {
    return const DisabledErrorReporter();
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  return configureCrashlytics(crashlytics: FirebaseCrashlytics.instance);
}

Future<ErrorReporter> configureCrashlytics({
  required FirebaseCrashlytics crashlytics,
  bool isReleaseMode = kReleaseMode,
}) async {
  await crashlytics.setCrashlyticsCollectionEnabled(isReleaseMode);
  if (!isReleaseMode) {
    await crashlytics.deleteUnsentReports();
  }
  return CrashlyticsErrorReporter(
    crashlytics: crashlytics,
    isReleaseMode: isReleaseMode,
  );
}
