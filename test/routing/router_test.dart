import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/domain/models/favorite.dart';
import 'package:o_que_comer_app/routing/router.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';
import 'package:provider/provider.dart';

class _ImmediateFavoritesRepository implements FavoritesRepository {
  @override
  Future<List<Favorite>> getFavorites() async => const [];

  @override
  Future<void> add(Favorite favorite) async {}

  @override
  Future<void> remove(String id) async {}
}

void main() {
  late FavoritesViewModel favoritesViewModel;

  setUp(() {
    router.go(Routes.home);
    favoritesViewModel = FavoritesViewModel(
      repository: _ImmediateFavoritesRepository(),
    );
  });

  tearDown(() {
    favoritesViewModel.dispose();
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: favoritesViewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('starts at home inside the main shell', (tester) async {
    await pumpRouter(tester);

    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('maps shell routes to their screens', (tester) async {
    await pumpRouter(tester);

    final shellRoutes = {
      Routes.aiRecipe: 'Receitas com IA',
      Routes.inventory: 'Despensa',
      Routes.search: 'Abrir detalhes da receita',
    };

    for (final entry in shellRoutes.entries) {
      await goTo(tester, entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('maps catalog outside the shell', (tester) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.catalog);

    expect(find.text('Catálogo'), findsNWidgets(2));
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting a bottom navigation destination changes routes', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir detalhes da receita'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum favorito ainda'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('redirects the recipes collection to the default recipe', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipes);

    expect(find.text('Detalhes da receita'), findsOneWidget);
    expect(find.text('Modo mãos livres'), findsOneWidget);
  });

  testWidgets('opens the requested recipe and its hands-free child route', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipeDetails('42'));

    await tester.tap(find.text('Modo mãos livres'));
    await tester.pumpAndSettle();

    expect(find.text('Modo mãos livres'), findsNWidgets(2));
    expect(find.text('Detalhes da receita'), findsNothing);
  });

  testWidgets('search action opens the default recipe details', (tester) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.search);

    await tester.tap(find.text('Abrir detalhes da receita'));
    await tester.pumpAndSettle();

    expect(find.text('Detalhes da receita'), findsOneWidget);
  });
}
