import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'debug_speech_panel.dart';

class HandsFreeModeScreen extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo mãos livres'),
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
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modo mãos livres'),
            // TEMPORÁRIO (APP-42): remover após validar a leitura no iOS.
            if (kDebugMode) DebugSpeechPanel(),
          ],
        ),
      ),
    );
  }
}
