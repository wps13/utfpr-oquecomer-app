import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/widgets/hands_free_step_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, HandsFreeStepCard card) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(child: SizedBox(width: 380, child: card)),
          ),
        ),
      );

  testWidgets('shows progress and respects navigation availability', (
    tester,
  ) async {
    var previous = 0;
    var next = 0;
    await pump(
      tester,
      HandsFreeStepCard(
        stepIndex: 0,
        stepCount: 3,
        text: 'Lave o arroz.',
        isReading: false,
        onToggleReading: () {},
        onNext: () => next++,
      ),
    );
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    expect(find.text('Lave o arroz.'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(1 / 3, 0.001),
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Passo anterior'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Próximo passo'));
    expect(next, 1);

    await pump(
      tester,
      HandsFreeStepCard(
        stepIndex: 2,
        stepCount: 3,
        text: 'Cozinhe.',
        isReading: false,
        onToggleReading: () {},
        onPrevious: () => previous++,
      ),
    );
    expect(find.text('Passo 3 de 3'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      1,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Próximo passo'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Passo anterior'));
    expect(previous, 1);
  });

  testWidgets('offers reading or pause with the corresponding callback', (
    tester,
  ) async {
    var reads = 0;
    var pauses = 0;
    await pump(
      tester,
      HandsFreeStepCard(
        stepIndex: 0,
        stepCount: 1,
        text: 'Lave o arroz.',
        isReading: false,
        onToggleReading: () => reads++,
      ),
    );
    await tester.tap(find.text('Ouvir passo'));
    expect(reads, 1);
    expect(find.text('Pausar leitura'), findsNothing);

    await pump(
      tester,
      HandsFreeStepCard(
        stepIndex: 0,
        stepCount: 1,
        text: 'Lave o arroz.',
        isReading: true,
        onToggleReading: () => pauses++,
      ),
    );
    await tester.tap(find.text('Pausar leitura'));
    expect(pauses, 1);
    expect(find.text('Ouvir passo'), findsNothing);
  });
}
