import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/screen_wake_lock/screen_wake_lock_service.dart';

void main() {
  test('ativa e desativa o wakelock pelo pacote', () async {
    final toggles = <bool>[];
    final service = WakelockPlusScreenWakeLockService(
      toggle: ({required enable}) async => toggles.add(enable),
    );

    await service.enable();
    await service.disable();

    expect(toggles, [true, false]);
  });

  test('não propaga falhas do pacote ao ativar ou desativar', () async {
    final service = WakelockPlusScreenWakeLockService(
      toggle: ({required enable}) => Future<void>.error(StateError('falha')),
    );

    await expectLater(service.enable(), completes);
    await expectLater(service.disable(), completes);
  });
}
