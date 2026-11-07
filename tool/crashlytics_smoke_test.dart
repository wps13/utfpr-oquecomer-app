import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:o_que_comer_app/config/error_handling.dart';
import 'package:o_que_comer_app/config/firebase_bootstrap.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';

/// Entry point de validação manual, separado da navegação do app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('ENABLE_CRASHLYTICS_SMOKE_TEST');
  if (!enabled) {
    throw StateError('Defina ENABLE_CRASHLYTICS_SMOKE_TEST=true para validar.');
  }
  final reporter = await initializeErrorReporting();
  installErrorHandlers(errorReporter: reporter);
  runApp(CrashlyticsSmokeTest(errorReporter: reporter));
}

class CrashlyticsSmokeTest extends StatelessWidget {
  const CrashlyticsSmokeTest({required this.errorReporter, super.key});

  final ErrorReporter errorReporter;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('APP-19: validar Crashlytics')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Coleta nativa: '
              '${FirebaseCrashlytics.instance.isCrashlyticsCollectionEnabled}',
            ),
            const Text(
              'Cada botão gera um erro de teste. Após um crash nativo, '
              'reabra o app para enviar o relatório em release.',
            ),
            ElevatedButton(
              onPressed: () async {
                await errorReporter.recordError(
                  StateError('APP-19: erro tratado de validação'),
                  StackTrace.current,
                  reason: 'Validação manual de erro não fatal',
                );
              },
              child: const Text('Registrar erro tratado'),
            ),
            ElevatedButton(
              onPressed: () => FlutterError.reportError(
                FlutterErrorDetails(
                  exception: StateError('APP-19: erro Flutter de validação'),
                  stack: StackTrace.current,
                ),
              ),
              child: const Text('Gerar erro Flutter'),
            ),
            ElevatedButton(
              onPressed: () {
                Timer.run(() {
                  throw StateError('APP-19: erro assíncrono de validação');
                });
              },
              child: const Text('Gerar erro assíncrono'),
            ),
            ElevatedButton(
              onPressed: FirebaseCrashlytics.instance.crash,
              child: const Text('Forçar crash nativo'),
            ),
          ],
        ),
      ),
    ),
  );
}
