import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/ai_recipes_header.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/image_selector.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/recipe_action_button.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/recipe_result.dart';
import 'package:o_que_comer_app/ui/ai_recipes/widgets/servings_selector.dart';

void main() {
  Widget app(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('exibe o cabeçalho da tela', (tester) async {
    await tester.pumpWidget(app(const AiRecipesHeader()));

    expect(find.text('O que tem na geladeira?'), findsOneWidget);
    expect(
      find.text(
        'Insira seus ingredientes e deixe a IA criar a magia culinária.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('altera a quantidade de porções pelos controles', (tester) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    var selectedServings = 0;

    await tester.pumpWidget(
      app(
        ServingsSelector(
          controller: controller,
          servings: 2,
          loading: false,
          onChange: (value) => selectedServings = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Aumentar quantidade de pessoas'));
    expect(selectedServings, 3);
    await tester.tap(find.byTooltip('Diminuir quantidade de pessoas'));
    expect(selectedServings, 1);
  });

  testWidgets('exibe o estado correto da ação de receita', (tester) async {
    await tester.pumpWidget(
      app(
        RecipeActionButton(
          loading: false,
          foodsDetected: true,
          enabled: true,
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('Gerar receita'), findsOneWidget);

    await tester.pumpWidget(
      app(
        RecipeActionButton(
          loading: true,
          foodsDetected: true,
          enabled: true,
          onPressed: () {},
        ),
      ),
    );
    expect(find.text('Processando...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('exibe erro e notifica tentativa novamente', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      app(
        RecipeErrorCard(
          message: 'Falha ao gerar',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Falha ao gerar'), findsOneWidget);
    await tester.tap(find.text('Tentar'));
    expect(retried, isTrue);
  });

  testWidgets('exibe receita, ingredientes e etapas', (tester) async {
    final recipe = Recipe(
      id: 'ai-1',
      title: 'Omelete',
      description: 'Rápida e simples',
      ingredients: const ['ovo', 'tomate'],
      steps: const ['Misture', 'Cozinhe'],
      source: RecipeSource.ai,
      servings: 2,
    );
    await tester.pumpWidget(app(RecipeResultCard(recipe: recipe)));

    expect(find.text('Omelete'), findsOneWidget);
    expect(find.text('Rápida e simples'), findsOneWidget);
    expect(find.text('2 pessoas'), findsOneWidget);
    expect(find.text('ovo'), findsOneWidget);
    expect(find.text('Misture'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets(
    'desabilita seleção de imagem quando não há permissão disponível',
    (tester) async {
      await tester.pumpWidget(
        app(
          const ImageSelector(
            imageBytes: null,
            permissionViewModel: null,
            onPickImage: _ignoreImageSource,
          ),
        ),
      );

      expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Tirar foto'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Galeria'),
            )
            .onPressed,
        isNull,
      );
    },
  );
}

void _ignoreImageSource(Object _) {}
