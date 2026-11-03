import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart' as native;

import '../../../domain/models/app_permission.dart';
import 'permission_service.dart';

class PermissionHandlerService implements PermissionService {
  PermissionHandlerService({
    TargetPlatform? platform,
    Future<int> Function()? androidSdkVersion,
  }) : _platform = platform ?? defaultTargetPlatform,
       _androidSdkVersion = androidSdkVersion ?? _readAndroidSdkVersion;

  final TargetPlatform _platform;
  final Future<int> Function() _androidSdkVersion;
  Future<void> _requestQueue = Future<void>.value();

  static Future<int> _readAndroidSdkVersion() async =>
      (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  bool get _isSupported =>
      !kIsWeb &&
      (_platform == TargetPlatform.android || _platform == TargetPlatform.iOS);

  Future<native.Permission?> _resolve(AppPermission permission) async {
    return switch (permission) {
      AppPermission.camera => native.Permission.camera,
      AppPermission.locationWhenInUse => native.Permission.locationWhenInUse,
      AppPermission.microphone => native.Permission.microphone,
      AppPermission.speechRecognition =>
        _platform == TargetPlatform.iOS ? native.Permission.speech : null,
      AppPermission.photos =>
        _platform == TargetPlatform.android && await _androidSdkVersion() < 33
            ? native.Permission.storage
            : native.Permission.photos,
      AppPermission.appStorage => null,
    };
  }

  PermissionAccess _map(native.PermissionStatus status) => switch (status) {
    native.PermissionStatus.granted => PermissionAccess.granted,
    native.PermissionStatus.denied => PermissionAccess.denied,
    native.PermissionStatus.permanentlyDenied =>
      PermissionAccess.permanentlyDenied,
    native.PermissionStatus.limited => PermissionAccess.limited,
    native.PermissionStatus.restricted => PermissionAccess.restricted,
    // Provisional é exclusivo de notificações, fora do escopo deste serviço.
    native.PermissionStatus.provisional => PermissionAccess.unavailable,
  };

  @override
  Future<PermissionAccess> check(AppPermission permission) async {
    if (!_isSupported) return PermissionAccess.unavailable;
    try {
      final nativePermission = await _resolve(permission);
      if (nativePermission == null) return PermissionAccess.granted;
      return _map(await nativePermission.status);
    } on PlatformException {
      return PermissionAccess.unavailable;
    } on MissingPluginException {
      return PermissionAccess.unavailable;
    }
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) {
    // O Android/iOS só aceita um diálogo nativo por vez.
    final result = _requestQueue.then((_) => _request(permission));
    _requestQueue = result.then<void>((_) {});
    return result;
  }

  Future<PermissionAccess> _request(AppPermission permission) async {
    if (!_isSupported) return PermissionAccess.unavailable;
    try {
      final nativePermission = await _resolve(permission);
      if (nativePermission == null) return PermissionAccess.granted;
      final current = _map(await nativePermission.status);
      if (current.isAuthorized ||
          current == PermissionAccess.permanentlyDenied ||
          current == PermissionAccess.restricted) {
        return current;
      }
      // No Android, status=denied também pode significar recusa permanente.
      // request() identifica esse caso sem apresentar outro diálogo nativo.
      return _map(await nativePermission.request());
    } on PlatformException {
      return PermissionAccess.unavailable;
    } on MissingPluginException {
      return PermissionAccess.unavailable;
    }
  }

  @override
  Future<bool> openSettings() async {
    if (!_isSupported) return false;
    try {
      return await native.openAppSettings();
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
