import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/firebase_bootstrap.dart';
import 'package:o_que_comer_app/data/services/errors/crashlytics_error_reporter.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';

class FakeCrashlytics extends Fake implements FirebaseCrashlytics {
  final List<({Object error, StackTrace? stack, Object? reason, bool fatal})>
  records = [];
  bool shouldFail = false;
  final List<String> policyCalls = [];

  @override
  Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    policyCalls.add('collection=$enabled');
  }

  @override
  Future<void> deleteUnsentReports() async {
    policyCalls.add('deleteUnsentReports');
  }

  @override
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    dynamic reason,
    Iterable<Object> information = const [],
    bool? printDetails,
    bool fatal = false,
  }) async {
    if (shouldFail) throw StateError('SDK unavailable');
    records.add((
      error: exception as Object,
      stack: stack,
      reason: reason as Object?,
      fatal: fatal,
    ));
  }
}

void main() {
  late FakeCrashlytics crashlytics;

  setUp(() => crashlytics = FakeCrashlytics());

  test(
    'debug bootstrap disables collection before deleting pending reports',
    () async {
      final reporter = await configureCrashlytics(
        crashlytics: crashlytics,
        isReleaseMode: false,
      );
      await reporter.recordError(StateError('Debug'), StackTrace.current);
      expect(crashlytics.policyCalls, [
        'collection=false',
        'deleteUnsentReports',
      ]);
      expect(crashlytics.records, isEmpty);
    },
  );

  test(
    'release bootstrap enables collection and preserves pending crashes',
    () async {
      final reporter = await configureCrashlytics(
        crashlytics: crashlytics,
        isReleaseMode: true,
      );
      await reporter.recordError(StateError('Release'), StackTrace.current);
      expect(crashlytics.policyCalls, ['collection=true']);
      expect(crashlytics.records, hasLength(1));
    },
  );

  test('debug/profile policy never calls Crashlytics', () async {
    final reporter = CrashlyticsErrorReporter(
      crashlytics: crashlytics,
      isReleaseMode: false,
    );
    await reporter.recordError(StateError('Handled'), StackTrace.current);
    await reporter.recordError(
      StateError('Unhandled'),
      StackTrace.current,
      fatal: true,
    );
    expect(crashlytics.records, isEmpty);
  });

  test('default mode in tests also disables reporting', () async {
    final reporter = CrashlyticsErrorReporter(crashlytics: crashlytics);
    await reporter.recordError(StateError('Debug'), StackTrace.current);
    expect(crashlytics.records, isEmpty);
  });

  test('release reports handled errors as nonfatal by default', () async {
    final reporter = CrashlyticsErrorReporter(
      crashlytics: crashlytics,
      isReleaseMode: true,
    );
    final error = StateError('Integration failure');
    final stack = StackTrace.current;
    await reporter.recordError(error, stack, reason: 'APP-19 test');
    expect(crashlytics.records, hasLength(1));
    final record = crashlytics.records.single;
    expect(record.error, same(error));
    expect(record.stack, same(stack));
    expect(record.reason, 'APP-19 test');
    expect(record.fatal, isFalse);
  });

  test('release preserves fatal classification', () async {
    final reporter = CrashlyticsErrorReporter(
      crashlytics: crashlytics,
      isReleaseMode: true,
    );
    await reporter.recordError(
      StateError('Fatal'),
      StackTrace.current,
      fatal: true,
    );
    expect(crashlytics.records.single.fatal, isTrue);
  });

  test('a reporting failure does not break the calling flow', () async {
    crashlytics.shouldFail = true;
    final reporter = CrashlyticsErrorReporter(
      crashlytics: crashlytics,
      isReleaseMode: true,
    );
    await expectLater(
      reporter.recordError(StateError('Original'), StackTrace.current),
      completes,
    );
  });

  test('disabled reporter is usable without initializing Firebase', () async {
    const reporter = DisabledErrorReporter();
    await expectLater(
      reporter.recordError(StateError('Unsupported'), StackTrace.current),
      completes,
    );
  });
}
