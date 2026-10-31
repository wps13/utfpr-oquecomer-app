import 'package:flutter/material.dart';

import '../themes/spacing.dart';

class LoadFeedback extends StatelessWidget {
  const LoadFeedback({
    required this.title,
    required this.onRetry,
    this.message,
    this.icon = Icons.restaurant_menu,
    super.key,
  });

  final String title;
  final String? message;
  final VoidCallback onRetry;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppSpacing.x3),
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
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
