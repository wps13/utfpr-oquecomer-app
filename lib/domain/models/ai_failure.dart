enum AiFailureKind {
  configuration,
  invalidInput,
  connection,
  timeout,
  quotaExceeded,
  unavailable,
  emptyResponse,
  invalidResponse,
  blocked,
  unexpected,
}

/// Erro tratável pela ViewModel, sem detalhes HTTP ou conteúdo do usuário.
class AiFailure implements Exception {
  const AiFailure(this.kind);

  final AiFailureKind kind;

  String get message => switch (kind) {
    AiFailureKind.configuration =>
      'Não foi possível acessar a IA. Verifique a configuração da API.',
    AiFailureKind.invalidInput =>
      'Informe ingredientes ou uma imagem válida para continuar.',
    AiFailureKind.connection =>
      'Não foi possível conectar à IA. Verifique sua conexão com a internet.',
    AiFailureKind.timeout => 'A IA demorou para responder. Tente novamente.',
    AiFailureKind.quotaExceeded =>
      'O limite de uso da IA foi atingido. Tente novamente mais tarde.',
    AiFailureKind.unavailable =>
      'A IA está indisponível no momento. Tente novamente mais tarde.',
    AiFailureKind.emptyResponse =>
      'A IA não retornou uma resposta. Tente novamente.',
    AiFailureKind.invalidResponse =>
      'Não foi possível interpretar a resposta da IA. Tente novamente.',
    AiFailureKind.blocked =>
      'A IA não pôde processar esse conteúdo. Tente outros ingredientes '
          'ou outra foto.',
    AiFailureKind.unexpected =>
      'Ocorreu um erro ao consultar a IA. Tente novamente.',
  };

  @override
  String toString() => 'AiFailure(${kind.name})';
}
