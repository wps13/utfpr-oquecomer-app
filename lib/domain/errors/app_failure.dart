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

/// Qualquer falha não prevista. É reportada ao `ErrorReporter`.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure(this.cause, [this.stackTrace])
    : super('Erro inesperado');

  final Object? cause;
  final StackTrace? stackTrace;
}
