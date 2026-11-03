typedef VoiceResultListener = void Function(
  String text, {
  required bool isFinal,
});

enum VoiceEngineStatus { listening, notListening, done }

/// Fronteira nativa substituível em testes; callbacks não contêm lógica de UI.
abstract interface class VoiceRecognitionEngine {
  Future<bool> initialize({
    required void Function(VoiceEngineStatus status) onStatus,
    required void Function(String code) onError,
  });

  Future<List<String>> locales();

  Future<void> listen({
    required String localeId,
    required VoiceResultListener onResult,
  });

  /// Descarta resultados pendentes, inclusive antes de uma leitura em voz alta.
  Future<void> cancel();
}
