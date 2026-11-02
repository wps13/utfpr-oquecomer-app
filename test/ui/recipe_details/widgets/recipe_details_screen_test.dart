import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';
import 'package:o_que_comer_app/ui/recipe_details/view_models/recipe_details_viewmodel.dart';
import 'package:o_que_comer_app/ui/recipe_details/widgets/recipe_details_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';
import '../../../../testing/fakes/fake_favorites_repository.dart';

final _lasanha = Recipe(
  id: '7',
  title: 'Lasanha à bolonhesa',
  description: 'Clássico de domingo.',
  ingredients: ['500 g de massa', '500 g de carne moída', '1 cebola'],
  steps: ['Refogue a carne.', 'Monte as camadas.', 'Asse por 25 min.'],
  source: RecipeSource.catalog,
  preparationMinutes: 45,
  servings: 4,
);

void main() {
  late FakeCatalogRepository catalog;
  late FakeFavoritesRepository favoritesRepository;
  late FavoritesViewModel favorites;

  setUp(() {
    catalog = FakeCatalogRepository()..recipes = [_lasanha];
    favoritesRepository = FakeFavoritesRepository();
    favorites = FavoritesViewModel(repository: favoritesRepository);
  });
  tearDown(() => favorites.dispose());

  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 844)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: Routes.recipeDetails(_lasanha.id),
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('home')),
        ),
        GoRoute(
          path: '/receitas/:id',
          builder: (context, state) => ChangeNotifierProvider(
            create: (_) => RecipeDetailsViewModel(
              recipeId: state.pathParameters['id']!,
              catalogRepository: catalog,
              favoritesRepository: favoritesRepository,
            ),
            child: const RecipeDetailsScreen(),
          ),
          routes: [
            GoRoute(
              path: 'hands-free',
              builder: (_, _) => const Scaffold(body: Text('hands-free')),
            ),
          ],
        ),
      ],
    );
    return tester.pumpWidget(
      ChangeNotifierProvider<FavoritesViewModel>.value(
        value: favorites,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  testWidgets('shows every recipe detail in order', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Lasanha à bolonhesa'), findsWidgets);
    expect(find.text('Clássico de domingo.'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('4 porções'), findsOneWidget);
    for (final ingredient in _lasanha.ingredients) {
      expect(find.text(ingredient), findsOneWidget);
    }

    await tester.scrollUntilVisible(find.text('Asse por 25 min.'), 200);
    final stepTops = [
      for (final step in _lasanha.steps) tester.getTopLeft(find.text(step)).dy,
    ];
    expect(stepTops, orderedEquals([...stepTops]..sort()));
    expect(find.text('1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('API text blocks become separate items and steps', (
    tester,
  ) async {
    catalog.recipes = [
      Recipe(
        id: '7',
        title: 'Frango agridoce',
        ingredients: ['500g de frango, 1 cebola, sal a gosto'],
        steps: ['1. Tempere o frango. 2. Refogue. 3. Sirva quente.'],
        source: RecipeSource.catalog,
      ),
    ];
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsNWidgets(3));
    await tester.scrollUntilVisible(find.text('Sirva quente.'), 200);
    expect(find.text('Tempere o frango.'), findsOneWidget);
    expect(find.text('Refogue.'), findsOneWidget);
  });

  testWidgets('favorite and hands-free buttons are visible', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Favoritar'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);
  });

  testWidgets('favorite button saves and removes the recipe', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favoritar'));
    await tester.pumpAndSettle();
    expect(favoritesRepository.items.map((r) => r.id), ['7']);
    expect(find.byTooltip('Remover dos favoritos'), findsOneWidget);

    await tester.tap(find.byTooltip('Remover dos favoritos'));
    await tester.pumpAndSettle();
    expect(favoritesRepository.items, isEmpty);
  });

  testWidgets('hands-free button opens the hands-free route', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('hands-free'), findsOneWidget);
  });

  testWidgets('checking an ingredient strikes it through', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1 cebola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 cebola'));
    await tester.pump();

    final text = tester.widget<Text>(find.text('1 cebola'));
    expect(text.style?.decoration, TextDecoration.lineThrough);
  });

  testWidgets('load error shows a message and retry works', (tester) async {
    var fail = true;
    catalog.loadRecipe = (id) async {
      if (fail) throw const NoConnectionFailure();
      return _lasanha;
    };
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar a receita'), findsOneWidget);
    expect(find.text('Sem conexão com a internet'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Modo de preparo'), findsOneWidget);
  });

  testWidgets('back from a direct link goes home', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('wide screens put ingredients beside the steps', (tester) async {
    await pump(tester, size: const Size(1280, 900));
    await tester.pumpAndSettle();

    final ingredients = tester.getTopLeft(find.text('Ingredientes'));
    final steps = tester.getTopLeft(find.text('Modo de preparo'));
    expect(ingredients.dx, greaterThan(steps.dx));
  });

  testWidgets('long recipes do not overflow on small screens', (tester) async {
    catalog.recipes = [
      Recipe(
        id: '7',
        title: 'Um nome de receita bastante longo para quebrar linha ' * 2,
        ingredients: List.generate(15, (i) => 'Ingrediente ${i + 1} ' * 4),
        steps: List.generate(10, (i) => 'Passo ${i + 1} ' * 20),
        source: RecipeSource.catalog,
        preparationMinutes: null,
      ),
    ];
    await pump(tester, size: const Size(320, 640));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tempo não informado'), findsOneWidget);
    expect(find.text('1 porção'), findsOneWidget);
  });
}
