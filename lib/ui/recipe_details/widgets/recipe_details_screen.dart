import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:o_que_comer_app/routing/routes.dart';

class RecipeDetailsScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da receita'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.home);
            }
          },
        ),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            final recipeId = GoRouterState.of(context).pathParameters['id']!;
            context.go(Routes.handsFreeMode(recipeId));
          },
          child: const Text('Modo mãos livres'),
        ),
      ),
    );
  }
}
