import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';
import 'package:o_que_comer_app/ui/favorites/widgets/favorites_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_favorites_repository.dart';

Recipe _recipe(String id, String title, {String? type}) => Recipe(
  id: id,
  title: title,
  type: type,
  ingredients: const ['Ingrediente'],
  steps: const ['Prepare.'],
  source: RecipeSource.catalog,
);

void main() {
  late FakeFavoritesRepository repository;
  late FavoritesViewModel viewModel;

  setUp(() {
    repository = FakeFavoritesRepository();
    viewModel = FavoritesViewModel(repository: repository);
  });

  tearDown(() => viewModel.dispose());

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<Recipe> favorites = const [],
    String initialLocation = Routes.favorites,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    repository.items.addAll(favorites);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: Routes.favorites,
          builder: (_, _) => const FavoritesScreen(),
        ),
        GoRoute(
          path: Routes.search,
          builder: (_, _) => const Scaffold(body: Text('Buscar receitas')),
        ),
        GoRoute(
          path: '/receitas/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Detalhes ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: viewModel,
        child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista nome e categoria das receitas favoritas', (tester) async {
    await pumpScreen(
      tester,
      favorites: [
        _recipe('1', 'Bolo de chocolate', type: 'Sobremesa'),
        _recipe('2', 'Salada Caesar'),
      ],
    );

    expect(find.text('Meus Favoritos'), findsOneWidget);
    expect(find.text('Bolo de chocolate'), findsOneWidget);
    expect(find.text('Sobremesa'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Salada Caesar'), 300);
    expect(find.text('Salada Caesar'), findsOneWidget);
    expect(find.byTooltip('Remover dos favoritos'), findsNWidgets(2));
  });

  testWidgets('desfavoritar remove a receita imediatamente', (tester) async {
    await pumpScreen(tester, favorites: [_recipe('1', 'Bolo')]);

    await tester.tap(find.byTooltip('Remover dos favoritos'));
    await tester.pump();

    expect(find.text('Bolo'), findsNothing);
    expect(repository.items, isEmpty);
  });

  testWidgets('tocar na receita abre os detalhes', (tester) async {
    await pumpScreen(tester, favorites: [_recipe('7', 'Lasanha')]);

    await tester.ensureVisible(find.text('Lasanha'));
    await tester.tap(find.text('Lasanha'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes 7'), findsOneWidget);
  });

  testWidgets('estado vazio orienta procurar receitas', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Nenhum favorito ainda'), findsOneWidget);
    expect(find.text('Procurar receitas'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);

    await tester.tap(find.text('Procurar receitas'));
    await tester.pumpAndSettle();

    expect(find.text('Buscar receitas'), findsOneWidget);
  });

  testWidgets('erro exibe ação de tentar novamente', (tester) async {
    repository.error = Exception('falhou');
    await pumpScreen(tester);

    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Procurar receitas'), findsNothing);
  });
}
