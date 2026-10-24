import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/detected_ingredients.dart';

void main() {
  Widget buildWidget({
    required List<String> ingredients,
    required ValueChanged<String> onRemove,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DetectedIngredients(ingredients: ingredients, onRemove: onRemove),
      ),
    );
  }

  testWidgets('exibe ingredientes detectados como chips removíveis', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildWidget(ingredients: ['tomate', 'ovo'], onRemove: (_) {}),
    );

    expect(find.text('Ingredientes detectados'), findsOneWidget);
    expect(find.byType(InputChip), findsNWidgets(2));
    expect(find.text('tomate'), findsOneWidget);
    expect(find.text('ovo'), findsOneWidget);
    expect(find.byTooltip('Remover tomate'), findsOneWidget);
    expect(find.byTooltip('Remover ovo'), findsOneWidget);
  });

  testWidgets('notifica o ingrediente removido', (tester) async {
    String? removedIngredient;
    await tester.pumpWidget(
      buildWidget(
        ingredients: ['tomate'],
        onRemove: (ingredient) => removedIngredient = ingredient,
      ),
    );

    await tester.tap(find.byTooltip('Remover tomate'));

    expect(removedIngredient, 'tomate');
  });

  testWidgets('orienta quando não há ingredientes restantes', (tester) async {
    await tester.pumpWidget(
      buildWidget(ingredients: const [], onRemove: (_) {}),
    );

    expect(
      find.text('Mantenha pelo menos um ingrediente para gerar a receita.'),
      findsOneWidget,
    );
    expect(find.byType(InputChip), findsNothing);
  });
}
