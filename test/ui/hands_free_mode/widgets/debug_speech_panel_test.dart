import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/hands_free_viewmodel.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/widgets/debug_speech_panel.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_speech_service.dart';

void main() {
  late FakeSpeechService speech;

  Future<void> pumpPanel(WidgetTester tester) async {
    speech = FakeSpeechService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => HandsFreeViewModel(speechService: speech),
            child: const DebugSpeechPanel(),
          ),
        ),
      ),
    );
  }

  testWidgets('drives the reading and shows its status', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Status: idle'), findsOneWidget);

    await tester.tap(find.text('Ler passo 1 (longo)'));
    await tester.pump();
    expect(find.text('Status: speaking'), findsOneWidget);

    await tester.tap(find.text('Ler passo 2 (curto)'));
    await tester.tap(find.text('Pausar'));
    await tester.pump();
    expect(find.text('Status: paused'), findsOneWidget);

    await tester.tap(find.text('Parar'));
    await tester.pump();
    expect(find.text('Status: idle'), findsOneWidget);
    expect(speech.spoken, [
      DebugSpeechPanel.longStep,
      DebugSpeechPanel.shortStep,
    ]);
  });

  testWidgets('shows the reading failure', (tester) async {
    await pumpPanel(tester);
    speech.failure = const SpeechEngineUnavailableFailure();

    await tester.tap(find.text('Ler passo 1 (longo)'));
    await tester.pump();

    expect(
      find.text('Erro: ${const SpeechEngineUnavailableFailure().message}'),
      findsOneWidget,
    );
  });
}
