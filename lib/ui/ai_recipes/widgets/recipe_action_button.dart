import 'package:flutter/material.dart';

class RecipeActionButton extends StatelessWidget {
  const RecipeActionButton({
    required this.loading,
    required this.foodsDetected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final bool loading;
  final bool foodsDetected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(
        loading
            ? 'Processando...'
            : foodsDetected
            ? 'Gerar receita'
            : 'Detectar ingredientes',
      ),
    ),
  );
}
