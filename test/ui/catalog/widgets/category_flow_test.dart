import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/recipe_category.dart';
import 'package:o_que_comer_app/routing/router.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';
import '../../../../testing/fakes/fake_favorites_repository.dart';

Recipe sampleRecipe({String id = '1', String type = 'doce', int? minutes}) =>
    Recipe(
      id: id,
      title: type == 'doce' ? 'Bolo de cenoura' : 'Frango grelhado',
      ingredients: ['Ingredientes da receita'],
      steps: ['Prepare a receita.'],
      source: RecipeSource.catalog,
      type: type,
      preparationMinutes: minutes,
    );

void main() {
  late FakeCatalogRepository repository;
  late FavoritesViewModel favorites;

  setUp(() {
    router.go(Routes.home);
    repository = FakeCatalogRepository()
      ..categories = [
        const RecipeCategory('doce'),
        const RecipeCategory('salgado'),
        const RecipeCategory('agridoce'),
      ]
      ..recipes = [
        sampleRecipe(),
        sampleRecipe(id: '2', type: 'salgado', minutes: 25),
      ];
    favorites = FavoritesViewModel(repository: FakeFavoritesRepository());
  });
  tearDown(() => favorites.dispose());

  Future<void> pumpApp(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<CatalogRepository>.value(value: repository),
          ChangeNotifierProvider<FavoritesViewModel>.value(value: favorites),
        ],
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('a prévia da home usa favoritos reais e abre a lista existente', (
    tester,
  ) async {
    await favorites.saveRecipe(sampleRecipe());
    await pumpApp(tester);
    expect(find.text('Bolo de cenoura'), findsOneWidget);
    expect(find.text('Suas receitas favoritas aparecerão aqui.'), findsNothing);
    await tester.tap(find.text('Ver mais'));
    await tester.pumpAndSettle();
    expect(find.text('Favoritos'), findsWidgets);
    expect(find.text('Bolo de cenoura'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home permanece utilizável com fonte ampliada e tela estreita', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpApp(tester);
    tester.view.physicalSize = const Size(320, 700);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Doce'), 150);
    await tester.pumpAndSettle();
    expect(find.text('Doce'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home apresenta todas as categorias retornadas e preserva a referência',
    (tester) async {
      await pumpApp(tester);
      for (final label in [
        'O Que Comer',
        'Favoritas',
        'Gerar com IA',
        'Categorias',
        'Doce',
        'Salgado',
        'Agridoce',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        find.text('Suas receitas favoritas aparecerão aqui.'),
        findsOneWidget,
      );
      expect(repository.categoryCalls, 1);
    },
  );

  testWidgets(
    'tocar na categoria mostra somente suas receitas e permite voltar',
    (tester) async {
      await pumpApp(tester);
      await select(tester, 'Doce');
      expect(repository.requestedCategories, ['doce']);
      expect(find.text('Bolo de cenoura'), findsOneWidget);
      expect(find.text('Frango grelhado'), findsNothing);
      expect(find.text('Tempo não informado'), findsOneWidget);
      expect(find.text('1 min'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Imagem indisponível')),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Categorias'), findsOneWidget);
    },
  );

  testWidgets(
    'tempo conhecido aparece no card e a receita abre a rota de detalhe',
    (tester) async {
      await pumpApp(tester);
      await select(tester, 'Salgado');
      expect(find.text('25 min'), findsOneWidget);
      await tester.tap(find.text('Frango grelhado'));
      await tester.pumpAndSettle();
      expect(find.text('Detalhes da receita'), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Frango grelhado'), findsOneWidget);
    },
  );

  testWidgets(
    'indicador de carregamento permanece enquanto consulta categorias',
    (tester) async {
      final pending = Completer<List<RecipeCategory>>();
      repository.loadCategories = () => pending.future;
      await pumpApp(tester, settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Carregando categorias'), findsOneWidget);
      pending.complete(repository.categories);
      await tester.pumpAndSettle();
      expect(find.text('Doce'), findsOneWidget);
    },
  );

  testWidgets('consulta da categoria mostra carregamento e depois a lista', (
    tester,
  ) async {
    final pending = Completer<List<Recipe>>();
    repository.loadRecipes = (_) => pending.future;
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Doce'));
    await tester.tap(find.text('Doce'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.bySemanticsLabel('Carregando receitas'), findsOneWidget);
    pending.complete([sampleRecipe()]);
    await tester.pumpAndSettle();
    expect(find.text('Bolo de cenoura'), findsOneWidget);
  });

  testWidgets('erro nas categorias permite tentar novamente', (tester) async {
    repository.loadCategories = () async => throw const NoConnectionFailure();
    await pumpApp(tester);
    expect(
      find.text('Não foi possível carregar as categorias'),
      findsOneWidget,
    );
    repository.loadCategories = null;
    await tester.ensureVisible(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Doce'), findsOneWidget);
    expect(repository.categoryCalls, 2);
  });

  testWidgets('home sem categorias exibe mensagem e nova tentativa', (
    tester,
  ) async {
    repository.categories = [];
    await pumpApp(tester);
    expect(
      find.text('Nenhuma categoria disponível no momento'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('categoria vazia permite consultar novamente', (tester) async {
    repository.recipes = [];
    await pumpApp(tester);
    await select(tester, 'Doce');
    expect(find.text('Nenhuma receita encontrada'), findsOneWidget);
    repository.recipes = [sampleRecipe()];
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Bolo de cenoura'), findsOneWidget);
  });

  testWidgets('erro de consulta mantém a categoria ao tentar novamente', (
    tester,
  ) async {
    repository.loadRecipes = (_) async => throw const TimeoutFailure();
    await pumpApp(tester);
    await select(tester, 'Doce');
    expect(find.text('Não foi possível carregar as receitas'), findsOneWidget);
    repository.loadRecipes = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(repository.requestedCategories, ['doce', 'doce']);
    expect(find.text('Bolo de cenoura'), findsOneWidget);
  });

  testWidgets('trocar a categoria pela URL recria a consulta correspondente', (
    tester,
  ) async {
    await pumpApp(tester);
    router.go(Routes.catalogByCategory('doce'));
    await tester.pumpAndSettle();
    router.go(Routes.catalogByCategory('salgado'));
    await tester.pumpAndSettle();
    expect(repository.requestedCategories, ['doce', 'salgado']);
    expect(find.text('Frango grelhado'), findsOneWidget);
    expect(find.text('Bolo de cenoura'), findsNothing);
  });

  testWidgets('imagem quebrada não impede a lista de receitas', (tester) async {
    repository.recipes = [
      Recipe(
        id: '1',
        title: 'Receita sem imagem',
        ingredients: ['Arroz'],
        steps: ['Cozinhe.'],
        source: RecipeSource.catalog,
        type: 'doce',
        imageUrl: 'https://image.test/nao-existe.jpg',
      ),
    ];
    await pumpApp(tester);
    await select(tester, 'Doce');
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Receita sem imagem'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Imagem indisponível')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
