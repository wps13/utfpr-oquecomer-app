import '../models/voice_command.dart';

/// Correspondência da frase inteira: "não parar" nunca vira "parar".
class VoiceCommandInterpreter {
  VoiceCommandInterpreter({
    Map<VoiceCommand, Set<String>> aliases = defaultAliases,
  }) {
    for (final entry in aliases.entries) {
      for (final phrase in entry.value) {
        final normalized = normalize(phrase);
        if (normalized.isEmpty ||
            (_commands.containsKey(normalized) &&
                _commands[normalized] != entry.key)) {
          throw ArgumentError(
            'Alias vazio ou atribuído a comandos diferentes.',
          );
        }
        _commands[normalized] = entry.key;
      }
    }
  }

  static const defaultAliases = <VoiceCommand, Set<String>>{
    VoiceCommand.resume: {
      'continuar',
      'continue',
      'continua',
      'retomar',
      'retome',
      'prosseguir',
      'pode continuar',
      'continuar por favor',
    },
    VoiceCommand.pause: {
      'parar',
      'pare',
      'para',
      'pausar',
      'pause',
      'pausa',
      'parar por favor',
    },
    VoiceCommand.nextStep: {
      'próximo passo',
      'próximo',
      'avançar',
      'avance',
      'avança',
      'passo seguinte',
      'seguinte',
      'ir para o próximo passo',
      'próximo passo por favor',
    },
    VoiceCommand.previousStep: {
      'passo anterior',
      'anterior',
      'voltar',
      'volte',
      'volta',
      'retroceder',
      'voltar um passo',
      'ir para o passo anterior',
    },
    VoiceCommand.exit: {'sair', 'saia', 'fechar'},
    VoiceCommand.exitMode: {
      'sair do modo',
      'sair do modo mãos livres',
      'sair do modo hands free',
      'encerrar modo',
      'encerrar modo mãos livres',
      'desativar modo mãos livres',
    },
  };

  final Map<String, VoiceCommand> _commands = {};

  VoiceCommand? interpret(String text) => _commands[normalize(text)];

  static String normalize(String text) {
    const accents = 'áàâãäåéèêëíìîïóòôõöúùûüçñ';
    const plain = 'aaaaaaeeeeiiiiooooouuuucn';
    final result = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      if (rune >= 0x0300 && rune <= 0x036f) continue;
      final character = String.fromCharCode(rune);
      final index = accents.indexOf(character);
      result.write(index < 0 ? character : plain[index]);
    }
    return result
        .toString()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
