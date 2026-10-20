import '../../../data/services/permissions/permission_service.dart';
import '../../../domain/models/app_permission.dart';

/// Compartilha o serviço com as ViewModels de features.
class PermissionViewModel {
  PermissionViewModel({required this.permissionService});

  final PermissionService permissionService;

  Future<PermissionAccess> check(AppPermission permission) =>
      permissionService.check(permission);

  Future<PermissionAccess> request(AppPermission permission) =>
      permissionService.request(permission);

  Future<bool> openSettings() => permissionService.openSettings();
}
