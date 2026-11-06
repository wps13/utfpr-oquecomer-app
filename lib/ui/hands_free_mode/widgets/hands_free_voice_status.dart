import 'package:flutter/material.dart';

import '../../../data/services/voice/voice_capture_service.dart';
import '../../../domain/models/voice_failure.dart';
import '../../core/themes/spacing.dart';

class HandsFreeVoiceStatus extends StatelessWidget {
  const HandsFreeVoiceStatus({
    required this.state,
    required this.enabled,
    required this.isReading,
    required this.onActivate,
    required this.onOpenSettings,
    this.failure,
    super.key,
  });

  final VoiceCaptureState state;
  final bool enabled;
  final bool isReading;
  final VoiceFailure? failure;
  final VoidCallback onActivate;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final listening =
        state == VoiceCaptureState.listening && enabled && !isReading;
    final title = isReading
        ? 'Lendo o passo'
        : !enabled
        ? 'Comandos de voz desativados'
        : switch (state) {
            VoiceCaptureState.listening => 'Ouvindo',
            VoiceCaptureState.starting => 'Preparando o microfone',
            VoiceCaptureState.restarting => 'Retomando a escuta',
            VoiceCaptureState.suspended => 'Escuta pausada',
            VoiceCaptureState.failed => 'Modo por voz indisponível',
            VoiceCaptureState.stopped => 'Microfone desligado',
          };
    return Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: listening ? colors.tertiaryContainer : colors.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    isReading
                        ? Icons.volume_up
                        : listening
                        ? Icons.mic
                        : Icons.mic_off,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                isReading
                    ? 'A escuta volta automaticamente ao terminar a leitura.'
                    : failure?.message ??
                          'Diga “continuar” para ouvir o passo '
                              'ou “próximo passo” para avançar.',
              ),
              if (failure != null || !enabled)
                Wrap(
                  spacing: AppSpacing.x2,
                  children: [
                    TextButton.icon(
                      onPressed: onActivate,
                      icon: const Icon(Icons.mic),
                      label: const Text('Ativar comandos de voz'),
                    ),
                    if (failure?.canOpenSettings == true)
                      TextButton.icon(
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings),
                        label: const Text('Abrir configurações'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
