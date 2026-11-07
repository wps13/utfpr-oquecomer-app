import 'package:flutter/material.dart';

import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';

/// Atalho para o modo hands-free (passo a passo guiado por voz).
class HandsFreeCard extends StatelessWidget {
  const HandsFreeCard({required this.onStart, super.key});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      color: scheme.primaryContainer,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: scheme.onPrimaryContainer.withValues(
                alpha: 0.12,
              ),
              foregroundColor: scheme.onPrimaryContainer,
              child: const Icon(Icons.record_voice_over_outlined),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo cozinha (hands-free)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    'Siga o passo a passo guiado por voz, sem tocar na tela.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x2),
            FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: scheme.surfaceContainerLowest,
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
              ),
              child: const Text('Iniciar'),
            ),
          ],
        ),
      ),
    );
  }
}
