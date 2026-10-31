import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/location_button.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/location_permission_dialog.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/location_unavailable_dialog.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('shows the action and current location', (tester) async {
    var pressed = false;
    await tester.pumpWidget(
      app(
        LocationButton(
          location: 'Curitiba, PR',
          loading: false,
          onPressed: () => pressed = true,
        ),
      ),
    );

    expect(find.text('Curitiba, PR'), findsOneWidget);
    expect(find.text('Localização usada:'), findsNothing);
    await tester.tap(find.byTooltip('Atualizar localização'));
    expect(pressed, isTrue);
  });

  testWidgets('shows the initial action without a location', (tester) async {
    await tester.pumpWidget(
      app(
        const LocationButton(location: null, loading: false, onPressed: null),
      ),
    );

    expect(find.text('Usar minha localização'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(
      tester.widget<TextButton>(find.byType(TextButton)).onPressed,
      isNull,
    );
  });

  testWidgets('shows a progress indicator while loading', (tester) async {
    await tester.pumpWidget(
      app(const LocationButton(location: null, loading: true, onPressed: null)),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('permission dialog returns the selected answer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => LocationPermissionDialog.show(context),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Permitir localização?'), findsOneWidget);
    await tester.tap(find.text('Permitir'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('permission dialog can be declined', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => LocationPermissionDialog.show(context),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Não permitir'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('unavailable dialog presents the failure and closes', (
    tester,
  ) async {
    const failure = LocationServiceDisabledFailure();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => LocationUnavailableDialog.show(context, failure),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Localização indisponível'), findsOneWidget);
    expect(find.textContaining(failure.message), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
