import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/routing/router.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/core/ui/recipe_list.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';

Recipe _recipe(String id, String title) => Recipe(
  id: id,
  title: title,
  ingredients: ['Limão'],
  steps: ['Prepare.'],
  source: RecipeSource.catalog,
  preparationMinutes: null,
);

void main() {
  late FakeCatalogRepository repository;

  setUp(() {
    router.go(Routes.search);
    repository = FakeCatalogRepository()
      ..recipes = [
        _recipe('1', 'Frango grelhado'),
        _recipe('2', 'Torta de Limão'),
        _recipe('3', 'Pão de queijo'),
      ];
  });

  Future<void> pumpApp(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      Provider<CatalogRepository>.value(
        value: repository,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('abre a lista original na estrutura usada pelas categorias', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Buscar receitas'), findsOneWidget);
    expect(find.text('3 receitas'), findsOneWidget);
    expect(
      tester.widget<RecipeList>(find.byType(RecipeList)).recipes,
      repository.recipes,
    );
    expect(repository.allRecipesCalls, 1);
  });

  testWidgets('digitar filtra nomes sem diferenciar caixa ou acento', (
    tester,
  ) async {
    await pumpApp(tester);
    for (final query in ['LIMAO', 'limão', 'LiMãO', 'lima\u0303o']) {
      await tester.enterText(find.byType(TextField), query);
      await tester.pumpAndSettle();
      expect(find.text('Torta de Limão'), findsOneWidget);
      expect(find.text('Frango grelhado'), findsNothing);
      expect(find.text('Pão de queijo'), findsNothing);
      expect(find.text('1 receita'), findsOneWidget);
    }
    expect(repository.allRecipesCalls, 1);
  });

  testWidgets('apagar o texto restaura a lista original sem outra consulta', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'pao');
    await tester.pumpAndSettle();
    expect(find.text('Pão de queijo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(find.text('3 receitas'), findsOneWidget);
    expect(
      tester.widget<RecipeList>(find.byType(RecipeList)).recipes,
      repository.recipes,
    );
    expect(repository.allRecipesCalls, 1);
  });

  testWidgets(
    'sem resultado exibe mensagem e o botão de limpar restaura a lista',
    (tester) async {
      await pumpApp(tester);
      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma receita encontrada'), findsOneWidget);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(find.text('3 receitas'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(repository.allRecipesCalls, 1);
    },
  );

  testWidgets(
    'digitação durante a consulta é aplicada quando a carga termina',
    (tester) async {
      final pending = Completer<List<Recipe>>();
      repository.loadAllRecipes = () => pending.future;
      await pumpApp(tester, settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Carregando receitas'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'LIMAO');
      pending.complete(repository.recipes);
      await tester.pumpAndSettle();
      expect(find.text('Torta de Limão'), findsOneWidget);
      expect(find.text('1 receita'), findsOneWidget);
    },
  );

  testWidgets('erro de conexão permite repetir sem perder o texto digitado', (
    tester,
  ) async {
    repository.loadAllRecipes = () async => throw const NoConnectionFailure();
    await pumpApp(tester);
    expect(find.text('Não foi possível carregar as receitas'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'limao');
    repository.loadAllRecipes = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Torta de Limão'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'limao',
    );
    expect(repository.allRecipesCalls, 2);
  });

  testWidgets('catálogo vazio oferece uma nova tentativa', (tester) async {
    repository.recipes = [];
    await pumpApp(tester);
    expect(find.text('Nenhuma receita encontrada'), findsOneWidget);
    repository.recipes = [_recipe('2', 'Torta de Limão')];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Torta de Limão'), findsOneWidget);
  });

  testWidgets('abrir uma receita e voltar preserva o texto e os resultados', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.enterText(find.byType(TextField), 'limao');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Torta de Limão'));
    await tester.pumpAndSettle();
    expect(find.text('Detalhes da receita'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Torta de Limão'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'limao',
    );
    expect(repository.allRecipesCalls, 1);
  });

  testWidgets(
    'busca e mensagem vazia cabem em tela estreita com fonte ampliada',
    (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpApp(tester);
      tester.view.physicalSize = const Size(320, 700);
      await tester.enterText(find.byType(TextField), 'zzzzzzz');
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma receita encontrada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
