import 'package:flutter/material.dart';

import '../../core/themes/spacing.dart';

class HandsFreeCommandsHelp extends StatelessWidget {
  const HandsFreeCommandsHelp({super.key});

  @override
  Widget build(BuildContext context) => const ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text('Comandos de voz'),
    children: [
      Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.x4),
        child: Text(
          '“Continuar” lê o passo desde o início. '
          '“Parar” pausa a leitura. “Próximo passo” e “passo anterior” '
          'mudam o passo. “Sair” ou “cancelar hands-free” encerram o modo.\n\n'
          'Fale quando o indicador mostrar “Ouvindo”. Durante a leitura, '
          'use o botão para pausar; a escuta volta ao final.',
        ),
      ),
    ],
  );
}
