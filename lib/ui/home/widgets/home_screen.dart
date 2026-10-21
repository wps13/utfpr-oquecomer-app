import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import 'generate_recipe_ai_button.dart';

class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () => context.go(Routes.catalog),
                child: const Text('Catálogo'),
              ),
              const SizedBox(height: AppSpacing.x3),
              const GenerateRecipeAiButton(),
              const SizedBox(height: AppSpacing.x3),
              ElevatedButton(
                onPressed: () => context.go(Routes.inventory),
                child: const Text('Despensa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
