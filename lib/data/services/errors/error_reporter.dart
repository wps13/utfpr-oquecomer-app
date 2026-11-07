/// Ponto único de registro de erros para as camadas do MVVM.
/// Injete esta interface em serviços, repositórios e ViewModels.
abstract interface class ErrorReporter {
  /// Erros tratados são não fatais por padrão. Não inclua credenciais,
  /// conteúdo de fotos ou dados pessoais no erro ou na justificativa.
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  });
}

/// Plataformas sem Crashlytics, como a execução local no navegador.
class DisabledErrorReporter implements ErrorReporter {
  const DisabledErrorReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {}
}
