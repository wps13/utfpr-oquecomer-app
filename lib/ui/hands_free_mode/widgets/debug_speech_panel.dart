import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/hands_free_viewmodel.dart';

/// TEMPORÁRIO (APP-42): controles para validar a leitura em voz alta no
/// iOS antes da tela do modo mãos livres existir. Aparece só em debug.
/// Remover este arquivo e o uso em `HandsFreeModeScreen` após a validação.
class DebugSpeechPanel extends StatelessWidget {
  const DebugSpeechPanel({super.key});

  static const longStep =
      'Passo um. Em uma panela, aqueça o azeite e refogue a cebola picada '
      'até ficar dourada, mexendo de vez em quando por cerca de cinco minutos.';
  static const shortStep = 'Passo dois. Acrescente o arroz e mexa bem.';

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HandsFreeViewModel>();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Status: ${viewModel.speechStatus.name}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text('Erro: ${viewModel.errorMessage ?? '-'}'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => viewModel.readStep(longStep),
            child: const Text('Ler passo 1 (longo)'),
          ),
          FilledButton(
            onPressed: () => viewModel.readStep(shortStep),
            child: const Text('Ler passo 2 (curto)'),
          ),
          OutlinedButton(
            onPressed: viewModel.pause,
            child: const Text('Pausar'),
          ),
          OutlinedButton(onPressed: viewModel.stop, child: const Text('Parar')),
        ],
      ),
    );
  }
}
