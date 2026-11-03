import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract interface class ScreenWakeLockService {
  Future<void> enable();
  Future<void> disable();
}

typedef WakelockToggle = Future<void> Function({required bool enable});

class WakelockPlusScreenWakeLockService implements ScreenWakeLockService {
  WakelockPlusScreenWakeLockService({
    this.toggle = WakelockPlus.toggle,
  });

  final WakelockToggle toggle;

  @override
  Future<void> enable() => _toggleSafely(enable: true);

  @override
  Future<void> disable() => _toggleSafely(enable: false);

  Future<void> _toggleSafely({required bool enable}) async {
    try {
      await toggle(enable: enable);
    } on Object catch (error, stackTrace) {
      debugPrint(
        '[screen-wake-lock] falha ao ${enable ? 'ativar' : 'desativar'}: '
        '$error\n$stackTrace',
      );
    }
  }
}
