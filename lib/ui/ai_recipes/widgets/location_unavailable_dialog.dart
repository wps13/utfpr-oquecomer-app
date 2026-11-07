import 'package:flutter/material.dart';

import '../../../domain/errors/app_failure.dart';

class LocationUnavailableDialog extends StatelessWidget {
  const LocationUnavailableDialog({required this.failure, super.key});

  final LocationFailure failure;

  static Future<void> show(BuildContext context, LocationFailure failure) =>
      showDialog<void>(
        context: context,
        builder: (_) => LocationUnavailableDialog(failure: failure),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Localização indisponível'),
    content: Text(
      '${failure.message}.\n\n'
      'Verifique as permissões de localização e se o serviço de localização '
      'está ativado no dispositivo. Você pode continuar usando o app sem '
      'esse recurso.',
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Fechar'),
      ),
    ],
  );
}
