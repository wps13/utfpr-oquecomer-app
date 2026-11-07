import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/permissions/permission_handler_service.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late PermissionStatus currentStatus;
  late PermissionStatus requestedStatus;
  late PermissionHandlerService service;
  late int sdk;

  setUp(() {
    calls = [];
    currentStatus = PermissionStatus.denied;
    requestedStatus = PermissionStatus.granted;
    sdk = 33;
    service = PermissionHandlerService(
      platform: TargetPlatform.android,
      androidSdkVersion: () async => sdk,
    );
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'checkPermissionStatus' => currentStatus.index,
        'requestPermissions' => <int, int>{
          for (final permission in call.arguments as List<Object?>)
            permission! as int: requestedStatus.index,
        },
        'openAppSettings' => true,
        _ => throw MissingPluginException(),
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('construction does not access or request any permission', () {
    expect(calls, isEmpty);
  });

  test('speech recognition on Android needs no extra permission', () async {
    expect(
      await service.check(AppPermission.speechRecognition),
      PermissionAccess.granted,
    );
    expect(
      await service.request(AppPermission.speechRecognition),
      PermissionAccess.granted,
    );
    expect(calls, isEmpty);
  });

  test('speech recognition uses the dedicated iOS authorization', () async {
    service = PermissionHandlerService(platform: TargetPlatform.iOS);
    expect(
      await service.request(AppPermission.speechRecognition),
      PermissionAccess.granted,
    );
    expect(calls.first.arguments, Permission.speech.value);
    expect(calls.last.arguments, [Permission.speech.value]);
  });

  test('check reads status without requesting permission', () async {
    expect(await service.check(AppPermission.camera), PermissionAccess.denied);
    expect(calls.map((call) => call.method), ['checkPermissionStatus']);
  });

  test('granted permission does not prompt again', () async {
    currentStatus = PermissionStatus.granted;
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.granted,
    );
    expect(calls.map((call) => call.method), ['checkPermissionStatus']);
  });

  test('request returns granted when the user allows access', () async {
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.granted,
    );
    expect(calls.last.method, 'requestPermissions');
    expect(calls.last.arguments, [Permission.camera.value]);
  });

  test('request returns denied without throwing', () async {
    requestedStatus = PermissionStatus.denied;
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.denied,
    );
  });

  test(
    'Android request identifies permanent denial after status=denied',
    () async {
      requestedStatus = PermissionStatus.permanentlyDenied;
      expect(
        await service.request(AppPermission.camera),
        PermissionAccess.permanentlyDenied,
      );
    },
  );

  test('blocked iOS permission is not requested again', () async {
    service = PermissionHandlerService(platform: TargetPlatform.iOS);
    currentStatus = PermissionStatus.permanentlyDenied;
    expect(
      await service.request(AppPermission.microphone),
      PermissionAccess.permanentlyDenied,
    );
    expect(calls, hasLength(1));
  });

  test('restricted access is preserved without another request', () async {
    currentStatus = PermissionStatus.restricted;
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.restricted,
    );
    expect(calls, hasLength(1));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('limited photo access is usable and preserved on $platform', () async {
      service = PermissionHandlerService(
        platform: platform,
        androidSdkVersion: () async => 34,
      );
      currentStatus = PermissionStatus.limited;
      final access = await service.request(AppPermission.photos);
      expect(access, PermissionAccess.limited);
      expect(access.isAuthorized, isTrue);
      expect(calls, hasLength(1));
    });
  }

  for (final version in [24, 29, 32, 33, 34, 36]) {
    test(
      'gallery uses the matching native permission on API $version',
      () async {
        sdk = version;
        await service.request(AppPermission.photos);
        final expected = version < 33 ? Permission.storage : Permission.photos;
        expect(calls.last.arguments, [expected.value]);
      },
    );
  }

  test('iOS photos do not query the Android version', () async {
    service = PermissionHandlerService(
      platform: TargetPlatform.iOS,
      androidSdkVersion: () => throw StateError('Must not query Android'),
    );
    await service.request(AppPermission.photos);
    expect(calls.last.arguments, [Permission.photos.value]);
  });

  test('location requests foreground access only', () async {
    await service.request(AppPermission.locationWhenInUse);
    expect(calls.last.arguments, [Permission.locationWhenInUse.value]);
  });

  test('microphone requests audio recording permission', () async {
    await service.request(AppPermission.microphone);
    expect(calls.last.arguments, [Permission.microphone.value]);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'private app files never request storage access on $platform',
      () async {
        service = PermissionHandlerService(platform: platform);
        expect(
          await service.check(AppPermission.appStorage),
          PermissionAccess.granted,
        );
        expect(
          await service.request(AppPermission.appStorage),
          PermissionAccess.granted,
        );
        expect(calls, isEmpty);
      },
    );
  }

  test(
    'permission status is refreshed after returning from settings',
    () async {
      expect(
        await service.check(AppPermission.camera),
        PermissionAccess.denied,
      );
      expect(await service.openSettings(), isTrue);
      currentStatus = PermissionStatus.granted;
      expect(
        await service.check(AppPermission.camera),
        PermissionAccess.granted,
      );
    },
  );

  test('concurrent requests are serialized', () async {
    final requests = [
      service.request(AppPermission.camera),
      service.request(AppPermission.microphone),
    ];
    expect(await Future.wait(requests), [
      PermissionAccess.granted,
      PermissionAccess.granted,
    ]);
    expect(calls.map((call) => call.method), [
      'checkPermissionStatus',
      'requestPermissions',
      'checkPermissionStatus',
      'requestPermissions',
    ]);
  });

  test(
    'platform errors return recoverable results and do not block the queue',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'unavailable');
      });
      expect(
        await service.check(AppPermission.camera),
        PermissionAccess.unavailable,
      );
      expect(
        await service.request(AppPermission.camera),
        PermissionAccess.unavailable,
      );
      expect(
        await service.request(AppPermission.microphone),
        PermissionAccess.unavailable,
      );
      expect(await service.openSettings(), isFalse);
    },
  );

  test('missing native plugin does not crash the flow', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(
      await service.check(AppPermission.camera),
      PermissionAccess.unavailable,
    );
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.unavailable,
    );
    expect(await service.openSettings(), isFalse);
  });

  test('unsupported platform does not call native APIs', () async {
    service = PermissionHandlerService(platform: TargetPlatform.linux);
    expect(
      await service.request(AppPermission.camera),
      PermissionAccess.unavailable,
    );
    expect(await service.openSettings(), isFalse);
    expect(calls, isEmpty);
  });
}
