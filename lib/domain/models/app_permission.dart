/// Recursos que podem ser autorizados durante o uso de uma funcionalidade.
enum AppPermission {
  camera,
  locationWhenInUse,
  microphone,
  photos,

  /// Arquivos privados do app não exigem permissão do sistema.
  appStorage,
}

enum PermissionAccess {
  granted,
  denied,
  permanentlyDenied,
  limited,
  restricted,
  unavailable,
}

extension PermissionAccessCapabilities on PermissionAccess {
  /// Acesso limitado permite usar somente as fotos escolhidas pelo usuário.
  bool get isAuthorized =>
      this == PermissionAccess.granted || this == PermissionAccess.limited;
}
