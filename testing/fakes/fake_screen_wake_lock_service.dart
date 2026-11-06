import 'package:o_que_comer_app/data/services/screen_wake_lock/screen_wake_lock_service.dart';

class FakeScreenWakeLockService implements ScreenWakeLockService {
  int enableCalls = 0;
  int disableCalls = 0;
  bool enabled = false;

  @override
  Future<void> enable() async {
    enableCalls++;
    enabled = true;
  }

  @override
  Future<void> disable() async {
    disableCalls++;
    enabled = false;
  }
}
