/// Erros de domínio produzidos pela camada de dados e tratados pelas
/// ViewModels. Use `switch` exaustivo para tratar cada caso.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sem conexão com a internet (ou servidor inalcançável).
final class NoConnectionFailure extends AppFailure {
  const NoConnectionFailure([super.message = 'Sem conexão com a internet']);
}

/// Tempo de conexão, envio ou resposta esgotado.
final class TimeoutFailure extends AppFailure {
  const TimeoutFailure([super.message = 'Tempo de resposta esgotado']);
}

/// Resposta 4xx: a requisição foi rejeitada pelo servidor.
final class ClientFailure extends AppFailure {
  const ClientFailure(this.statusCode, [String? message])
    : super(message ?? 'Requisição inválida');

  final int statusCode;

  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  bool get isRateLimited => statusCode == 429;
}

/// Resposta 5xx: falha no servidor.
final class ServerFailure extends AppFailure {
  const ServerFailure(this.statusCode, [String? message])
    : super(message ?? 'Erro no servidor');

  final int statusCode;
}

/// Requisição cancelada pelo app.
final class CancelledFailure extends AppFailure {
  const CancelledFailure([super.message = 'Requisição cancelada']);
}

/// Dados informados ao repositório não permitem uma requisição válida.
final class InvalidInputFailure extends AppFailure {
  const InvalidInputFailure([super.message = 'Dados de consulta inválidos']);
}

/// Corpo vazio, JSON inválido ou resposta incompatível com o contrato da API.
final class InvalidResponseFailure extends AppFailure {
  const InvalidResponseFailure([
    super.message = 'O servidor retornou uma resposta inválida',
  ]) : isEmptyBody = false;

  /// Resposta sem corpo. Em consultas por id, a API usa isso para "não existe".
  const InvalidResponseFailure.emptyBody([
    super.message = 'O servidor retornou uma resposta vazia',
  ]) : isEmptyBody = true;

  final bool isEmptyBody;
}

/// Qualquer falha não prevista. É reportada ao `ErrorReporter`.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.cause, [this.stackTrace])
    : super('Erro inesperado');

  final Object? cause;
  final StackTrace? stackTrace;
}

sealed class LocationFailure extends AppFailure {
  const LocationFailure(super.message);
}

final class LocationTimeoutFailure extends LocationFailure {
  const LocationTimeoutFailure([
    super.message = 'Tempo para obter a localização esgotado',
  ]);
}

final class LocationUnavailableFailure extends LocationFailure {
  const LocationUnavailableFailure(this.cause, [this.stackTrace])
    : super('Não foi possível obter a localização');

  final Object cause;
  final StackTrace? stackTrace;
}

final class LocationServiceDisabledFailure extends LocationFailure {
  const LocationServiceDisabledFailure([
    super.message = 'O serviço de localização está desativado',
  ]);
}

final class LocationPermissionDeniedFailure extends LocationFailure {
  const LocationPermissionDeniedFailure([
    super.message = 'Permissão de localização negada',
  ]);
}

final class GeocodingFailure extends LocationFailure {
  const GeocodingFailure([
    super.message = 'Não foi possível converter as coordenadas em endereço',
  ]);
}

sealed class SpeechFailure extends AppFailure {
  const SpeechFailure(super.message);
}

/// Não há motor de voz no aparelho, o plugin não respondeu ou a
/// inicialização excedeu o tempo limite.
final class SpeechEngineUnavailableFailure extends SpeechFailure {
  const SpeechEngineUnavailableFailure([this.cause, this.stackTrace])
    : super('A leitura em voz alta não está disponível neste aparelho');

  final Object? cause;
  final StackTrace? stackTrace;
}

/// O motor existe, mas a voz do idioma configurado não está instalada.
final class SpeechLanguageUnavailableFailure extends SpeechFailure {
  const SpeechLanguageUnavailableFailure(this.language)
    : super('A voz em português não está instalada neste aparelho');

  final String language;
}

/// O motor recusou ou não conseguiu reproduzir o texto.
final class SpeechPlaybackFailure extends SpeechFailure {
  const SpeechPlaybackFailure([this.cause])
    : super('Não foi possível ler o texto em voz alta');

  final Object? cause;
}
