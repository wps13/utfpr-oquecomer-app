import 'package:flutter/material.dart';

class AiRecipesHeader extends StatelessWidget {
  const AiRecipesHeader({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        'O que tem na geladeira?',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        'Insira seus ingredientes e deixe a IA criar a magia culinária.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    ],
  );
}
