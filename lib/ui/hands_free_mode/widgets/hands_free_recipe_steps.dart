import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/themes/spacing.dart';
import '../view_models/hands_free_mode_viewmodel.dart';
import 'hands_free_commands_help.dart';
import 'hands_free_step_card.dart';
import 'hands_free_voice_status.dart';

class HandsFreeRecipeSteps extends StatelessWidget {
  const HandsFreeRecipeSteps({
    required this.viewModel,
    required this.onExit,
    super.key,
  });

  final HandsFreeModeViewModel viewModel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(vm.recipeTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.x4),
        HandsFreeVoiceStatus(
          state: vm.voiceState,
          enabled: vm.voiceEnabled,
          isReading: vm.isReading,
          failure: vm.voiceFailure,
          onActivate: () => unawaited(vm.startVoice()),
          onOpenSettings: () => unawaited(vm.openSettings()),
        ),
        const SizedBox(height: AppSpacing.x4),
        HandsFreeStepCard(
          stepIndex: vm.stepIndex,
          stepCount: vm.steps.length,
          text: vm.currentStep,
          isReading: vm.isReading,
          onToggleReading: () =>
              unawaited(vm.isReading ? vm.pauseReading() : vm.readStep()),
          onPrevious: vm.hasPrevious
              ? () => unawaited(vm.previousStep())
              : null,
          onNext: vm.hasNext ? () => unawaited(vm.nextStep()) : null,
        ),
        if (vm.feedback != null || vm.readingError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: Text(
              vm.readingError ?? vm.feedback!,
              semanticsLabel: vm.readingError ?? vm.feedback,
              style: TextStyle(
                color: vm.readingError == null ? null : theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.x4),
        const HandsFreeCommandsHelp(),
        const SizedBox(height: AppSpacing.x3),
        TextButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.close),
          label: const Text('Sair do modo'),
        ),
      ],
    );
  }
}
