import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';

class GenerateRecipeAiButton extends StatelessWidget {
  const GenerateRecipeAiButton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: 'Gerar receita com IA',
      child: Material(
        color: AppColors.primary,
        borderRadius: AppRadius.borderXl,
        child: InkWell(
          onTap: () => context.go(Routes.aiRecipe),
          borderRadius: AppRadius.borderXl,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 108),
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.x3),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Gerar com IA',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
