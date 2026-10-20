import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';

class HomeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.go(Routes.catalog),
              child: const Text('Catálogo'),
            ),
            ElevatedButton(
              onPressed: () => context.go(Routes.aiRecipe),
              child: const Text('Receitas com IA'),
            ),
            ElevatedButton(
              onPressed: () => context.go(Routes.inventory),
              child: const Text('Despensa'),
            ),
          ],
        ),
      ),
    );
  }
}
