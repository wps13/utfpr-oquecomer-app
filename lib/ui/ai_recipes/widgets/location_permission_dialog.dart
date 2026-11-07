import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';

class LocationPermissionDialog extends StatelessWidget {
  const LocationPermissionDialog({super.key});

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (_) => const LocationPermissionDialog(),
  );

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
    contentPadding: const EdgeInsets.fromLTRB(
      AppSpacing.x6,
      AppSpacing.x6,
      AppSpacing.x6,
      AppSpacing.x3,
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primaryFixed,
          child: Icon(
            Icons.location_on_outlined,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        Text(
          'Permitir localização?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.x2),
        const Text(
          'O Que Comer usa sua localização para sugerir receitas baseadas '
          'nos ingredientes e sabores regionais.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x5),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Permitir'),
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não permitir'),
          ),
        ),
      ],
    ),
  );
}
