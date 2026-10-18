import '../../../domain/models/app_permission.dart';

/// Dependência das ViewModels; não apresenta UI nem solicita na inicialização.
abstract interface class PermissionService {
  /// Consulta sem abrir o diálogo nativo. No Android, uma recusa permanente
  /// só pode ser identificada pelo resultado de [request].
  Future<PermissionAccess> check(AppPermission permission);

  /// Deve ser chamado apenas após uma ação explícita para usar o recurso.
  Future<PermissionAccess> request(AppPermission permission);

  Future<bool> openSettings();
}
