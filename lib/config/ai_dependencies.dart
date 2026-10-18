import 'package:http/http.dart' as http;

import '../data/repositories/ai_repository.dart';
import '../data/repositories/gemini_ai_repository.dart';
import '../data/services/ai/gemini_service.dart';
import '../data/services/api/api_client.dart';
import '../data/services/errors/error_reporter.dart';
import 'gemini_config.dart';

/// Composição da integração. Criar este objeto não consulta a IA.
/// O proprietário chama close ao encerrar seu ciclo de vida.
class AiDependencies {
  AiDependencies({
    required ErrorReporter errorReporter,
    GeminiConfig config = const GeminiConfig.fromEnvironment(),
    http.Client? client,
  }) : _client = client ?? http.Client() {
    repository = GeminiAiRepository(
      service: GeminiService(
        apiClient: ApiClient(client: _client),
        config: config,
      ),
      errorReporter: errorReporter,
    );
  }

  final http.Client _client;
  late final AiRepository repository;

  void close() => _client.close();
}
