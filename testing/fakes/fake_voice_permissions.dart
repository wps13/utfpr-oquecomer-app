import 'package:o_que_comer_app/data/services/permissions/permission_service.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';

class FakeVoicePermissions implements PermissionService {
  final access = <AppPermission, PermissionAccess>{};
  PermissionAccess requestedAccess = PermissionAccess.granted;
  final requests = <AppPermission>[];
  final checks = <AppPermission>[];

  @override
  Future<PermissionAccess> check(AppPermission permission) async {
    checks.add(permission);
    return access[permission] ?? PermissionAccess.granted;
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) async {
    requests.add(permission);
    return requestedAccess;
  }

  @override
  Future<bool> openSettings() async => true;
}
