import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:o_que_comer_app/routing/routes.dart';

class CatalogScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo'),
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
      body: const Center(child: Text('Catálogo')),
    );
  }
}
