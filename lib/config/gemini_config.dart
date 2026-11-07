class GeminiConfig {
  const GeminiConfig({
    required this.apiKey,
    this.model = 'gemini-3.5-flash-lite',
    this.temperature = 0.4,
    this.maxOutputTokens = 4096,
    this.timeout = const Duration(seconds: 30),
  });

  const GeminiConfig.fromEnvironment()
    : apiKey = const String.fromEnvironment('GEMINI_API_KEY'),
      model = const String.fromEnvironment(
        'GEMINI_MODEL',
        defaultValue: 'gemini-3.5-flash-lite',
      ),
      temperature = 0.4,
      maxOutputTokens = 4096,
      timeout = const Duration(seconds: 30);

  final String apiKey;
  final String model;
  final double temperature;
  final int maxOutputTokens;
  final Duration timeout;

  bool get isValid =>
      apiKey.trim().isNotEmpty &&
      RegExp(r'^gemini-[a-zA-Z0-9.\-]+$').hasMatch(model) &&
      temperature.isFinite &&
      temperature >= 0 &&
      temperature <= 2 &&
      maxOutputTokens > 0 &&
      maxOutputTokens <= 65536 &&
      timeout > Duration.zero;

  /// Diagnóstico seguro para logs locais: nunca retorna a chave.
  List<String> get invalidReasons {
    final reasons = <String>[];
    if (apiKey.trim().isEmpty) reasons.add('apiKey ausente ou vazia');
    if (!RegExp(r'^gemini-[a-zA-Z0-9.\-]+$').hasMatch(model)) {
      reasons.add('modelo inválido');
    }
    if (!temperature.isFinite || temperature < 0 || temperature > 2) {
      reasons.add('temperature fora do intervalo 0..2');
    }
    if (maxOutputTokens <= 0 || maxOutputTokens > 65536) {
      reasons.add('maxOutputTokens fora do intervalo 1..65536');
    }
    if (timeout <= Duration.zero) reasons.add('timeout deve ser positivo');
    return List.unmodifiable(reasons);
  }
}
