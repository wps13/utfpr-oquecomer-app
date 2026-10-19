/// Configuração injetada em tempo de build, fora do código versionado.
///
/// Uso:
/// `flutter run --dart-define-from-file=env.json`
/// (copie `env.example.json` para `env.json`, que está no .gitignore) ou
/// `flutter run --dart-define=GEMINI_API_KEY=...`.
class Env {
  const Env({
    required this.catalogBaseUrl,
    required this.geminiBaseUrl,
    required this.geminiApiKey,
  });

  /// Lê os valores passados via `--dart-define`.
  factory Env.fromEnvironment() => const Env(
    catalogBaseUrl: String.fromEnvironment('CATALOG_BASE_URL'),
    geminiBaseUrl: String.fromEnvironment(
      'GEMINI_BASE_URL',
      defaultValue: 'https://generativelanguage.googleapis.com/v1beta',
    ),
    geminiApiKey: String.fromEnvironment('GEMINI_API_KEY'),
  );

  final String catalogBaseUrl;
  final String geminiBaseUrl;
  final String geminiApiKey;
}
