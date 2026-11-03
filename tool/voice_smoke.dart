import 'dart:async';

import 'package:flutter/material.dart';

import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/permissions/permission_handler_service.dart';
import 'package:o_que_comer_app/data/services/voice/device_voice_capture_service.dart';
import 'package:o_que_comer_app/data/services/voice/speech_to_text_engine.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/domain/models/voice_command.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/voice_commands_viewmodel.dart';

/// Teste isolado, sem inicialização Dart do Firebase nem acesso à IA.
void main() => runApp(const MaterialApp(home: _VoiceSmokeScreen()));

class _VoiceSmokeScreen extends StatefulWidget {
  const _VoiceSmokeScreen();

  @override
  State<_VoiceSmokeScreen> createState() => _VoiceSmokeScreenState();
}

class _VoiceSmokeScreenState extends State<_VoiceSmokeScreen> {
  final _permissions = PermissionHandlerService();
  late final DeviceVoiceCaptureService _capture;
  late final VoiceCommandsViewModel _vm;
  late final StreamSubscription<VoiceCommand> _commands;
  late final StreamSubscription<String> _transcripts;
  String _lastCommand = 'Nenhum comando recebido';
  String _lastTranscript = 'Nenhuma frase recebida';
  double? _soundLevel;
  int _count = 0;

  String get _soundLevelLabel => _vm.state == VoiceCaptureState.listening
      ? _soundLevel?.toStringAsFixed(1) ?? '—'
      : '—';

  @override
  void initState() {
    super.initState();
    _capture = DeviceVoiceCaptureService(
      engine: SpeechToTextEngine(
        onSoundLevel: (level) {
          if (mounted) setState(() => _soundLevel = level);
        },
      ),
      permissions: _permissions,
      errorReporter: const DisabledErrorReporter(),
    );
    _vm = VoiceCommandsViewModel(capture: _capture);
    _transcripts = _capture.transcripts.listen((text) {
      if (mounted) setState(() => _lastTranscript = text);
    });
    _commands = _vm.commands.listen((command) {
      if (!mounted) return;
      setState(() {
        _count++;
        _lastCommand = command.name;
      });
    });
  }

  @override
  void dispose() {
    unawaited(_commands.cancel());
    unawaited(_transcripts.cancel());
    _vm.dispose();
    unawaited(_capture.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Teste de voz — APP-43')),
    body: ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Toque em Iniciar e autorize o microfone e a fala. '
            'Diga continuar, parar, próximo passo, passo anterior, sair '
            'ou sair do modo. Frases fora da lista devem ser ignoradas.',
          ),
          const SizedBox(height: 24),
          Text('Estado: ${_vm.state.name}'),
          Text('Comandos: $_count'),
          Text('Último: $_lastCommand'),
          Text('Última frase: $_lastTranscript'),
          Text('Nível do microfone: $_soundLevelLabel'),
          if (_vm.failure != null) ...[
            const SizedBox(height: 16),
            Text(_vm.failure!.message),
            if (_vm.failure!.canOpenSettings)
              TextButton(
                onPressed: () async {
                  await _permissions.openSettings();
                },
                child: const Text('Abrir configurações'),
              ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed:
                _vm.state == VoiceCaptureState.stopped ||
                    _vm.state == VoiceCaptureState.failed
                ? () => unawaited(_vm.start())
                : null,
            child: const Text('Iniciar'),
          ),
          OutlinedButton(
            onPressed: () => unawaited(_vm.stop()),
            child: const Text('Encerrar escuta'),
          ),
        ],
      ),
    ),
  );
}
