import 'app_permission.dart';

enum VoiceFailureKind {
  microphoneDenied,
  speechPermissionDenied,
  recognitionUnavailable,
  languageUnavailable,
  noSpeech,
  engine,
  unexpected,
}

/// Não contém áudio, transcrição nem mensagens nativas do reconhecedor.
class VoiceFailure implements Exception {
  const VoiceFailure(this.kind, {this.permissionAccess});

  final VoiceFailureKind kind;
  final PermissionAccess? permissionAccess;

  bool get canOpenSettings =>
      permissionAccess == PermissionAccess.permanentlyDenied ||
      permissionAccess == PermissionAccess.restricted;

  String get message => switch (kind) {
    VoiceFailureKind.microphoneDenied =>
      'Permita o acesso ao microfone para usar os comandos de voz.',
    VoiceFailureKind.speechPermissionDenied =>
      'Permita o reconhecimento de fala nos ajustes do dispositivo.',
    VoiceFailureKind.recognitionUnavailable =>
      'O reconhecimento de fala não está disponível neste dispositivo.',
    VoiceFailureKind.languageUnavailable =>
      'O reconhecimento em português do Brasil não está disponível. '
          'Verifique os idiomas do serviço de voz do dispositivo.',
    VoiceFailureKind.noSpeech =>
      'Não foi possível entender uma fala. A escuta será retomada.',
    VoiceFailureKind.engine =>
      'O reconhecimento de fala falhou. Verifique a conexão e tente novamente.',
    VoiceFailureKind.unexpected =>
      'Não foi possível iniciar os comandos de voz. Tente novamente.',
  };

  @override
  String toString() => 'VoiceFailure(${kind.name})';
}
