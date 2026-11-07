import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/spacing.dart';

class LocationButton extends StatelessWidget {
  const LocationButton({
    required this.location,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String? location;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (location case final currentLocation?)
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.x1),
            Expanded(
              child: Text(
                currentLocation,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            IconButton(
              onPressed: onPressed,
              tooltip: 'Atualizar localização',
              iconSize: 20,
              visualDensity: VisualDensity.compact,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        )
      else
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onPressed,
            icon: loading
                ? const SizedBox.square(
                    dimension: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.location_on_outlined, size: 16),
            label: const Text('Usar minha localização'),
          ),
        ),
    ],
  );
}
