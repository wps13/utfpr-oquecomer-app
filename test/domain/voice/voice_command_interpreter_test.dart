import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/voice_command.dart';
import 'package:o_que_comer_app/domain/voice/voice_command_interpreter.dart';

void main() {
  final interpreter = VoiceCommandInterpreter();

  for (final entry in VoiceCommandInterpreter.defaultAliases.entries) {
    test('aceita todas as variações de ${entry.key.name}', () {
      for (final phrase in entry.value) {
        expect(interpreter.interpret(phrase), entry.key, reason: phrase);
      }
    });
  }

  test('normaliza caixa, acentos, pontuação e espaços', () {
    for (final phrase in [
      ' PRÓXIMO   PASSO!!! ',
      'proximo passo',
      'pro\u0301ximo passo',
      'Próximo-passo.',
      'Próximo, passo?',
    ]) {
      expect(interpreter.interpret(phrase), VoiceCommand.nextStep);
    }
    expect(
      interpreter.interpret('SAIR DO MODO MÃOS LIVRES.'),
      VoiceCommand.exitMode,
    );
    expect(interpreter.interpret('AVANÇAR!'), VoiceCommand.nextStep);
  });

  test('não extrai comandos de frases desconhecidas, negadas ou compostas', () {
    for (final phrase in [
      '',
      ' ',
      '?!',
      'receita de bolo',
      'não parar',
      'não quero sair',
      'continuar cozinhando o arroz',
      'próximo ingrediente',
      'passo anterior e próximo passo',
      'parar e sair',
      'preparar',
    ]) {
      expect(interpreter.interpret(phrase), isNull, reason: phrase);
    }
  });

  test('sair e sair do modo permanecem intenções distintas', () {
    expect(interpreter.interpret('sair'), VoiceCommand.exit);
    expect(interpreter.interpret('sair do modo'), VoiceCommand.exitMode);
  });

  test('permite ampliar aliases sem alterar o interpretador', () {
    final extended = VoiceCommandInterpreter(
      aliases: {
        ...VoiceCommandInterpreter.defaultAliases,
        VoiceCommand.nextStep: {
          ...VoiceCommandInterpreter.defaultAliases[VoiceCommand.nextStep]!,
          'vamos adiante',
        },
      },
    );
    expect(extended.interpret('Vamos adiante!'), VoiceCommand.nextStep);
    expect(interpreter.interpret('vamos adiante'), isNull);
  });

  test('rejeita aliases vazios ou ambíguos após normalização', () {
    expect(
      () => VoiceCommandInterpreter(
        aliases: {
          VoiceCommand.resume: {'continuar'},
          VoiceCommand.pause: {'CONTINUAR!'},
        },
      ),
      throwsArgumentError,
    );
    expect(
      () => VoiceCommandInterpreter(
        aliases: {
          VoiceCommand.exit: {'!!!'},
        },
      ),
      throwsArgumentError,
    );
  });
}
