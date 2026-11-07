import 'package:flutter/material.dart';

import '../themes/spacing.dart';

class LoadFeedback extends StatelessWidget {
  const LoadFeedback({
    required this.title,
    required this.onRetry,
    this.message,
    this.icon = Icons.restaurant_menu,
    this.actionLabel = 'Tentar novamente',
    this.actionIcon = Icons.refresh,
    this.iconSize = 36,
    this.iconSpacing = AppSpacing.x3,
    super.key,
  });

  final String title;
  final String? message;
  final VoidCallback onRetry;
  final IconData icon;
  final String actionLabel;
  final IconData actionIcon;
  final double iconSize;

  /// Espaço entre o ícone e o título.
  final double iconSpacing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: Theme.of(context).colorScheme.primary,
        ),
        SizedBox(height: iconSpacing),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (message != null) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(message!, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.x4),
        FilledButton.icon(
          onPressed: onRetry,
          icon: Icon(actionIcon),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
}
