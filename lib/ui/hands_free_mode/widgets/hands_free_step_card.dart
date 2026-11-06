import 'package:flutter/material.dart';

import '../../core/themes/spacing.dart';

class HandsFreeStepCard extends StatelessWidget {
  const HandsFreeStepCard({
    required this.stepIndex,
    required this.stepCount,
    required this.text,
    required this.isReading,
    required this.onToggleReading,
    this.onPrevious,
    this.onNext,
    super.key,
  });

  final int stepIndex;
  final int stepCount;
  final String text;
  final bool isReading;
  final VoidCallback onToggleReading;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Passo ${stepIndex + 1} de $stepCount',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.x3),
            LinearProgressIndicator(
              value: (stepIndex + 1) / stepCount,
              semanticsLabel: 'Progresso dos passos',
            ),
            const SizedBox(height: AppSpacing.x6),
            Text(text, style: theme.textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.x6),
            FilledButton.icon(
              onPressed: onToggleReading,
              icon: Icon(isReading ? Icons.pause : Icons.volume_up),
              label: Text(isReading ? 'Pausar leitura' : 'Ouvir passo'),
            ),
            const SizedBox(height: AppSpacing.x3),
            Wrap(
              spacing: AppSpacing.x3,
              runSpacing: AppSpacing.x3,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.skip_previous),
                  label: const Text('Passo anterior'),
                ),
                OutlinedButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.skip_next),
                  label: const Text('Próximo passo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
