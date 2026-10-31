import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'routes.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../domain/models/recipe_category.dart';
import '../ui/ai_recipes/widgets/ai_recipes_screen.dart';
import '../ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';

import '../ui/catalog/widgets/catalog_screen.dart';
import '../ui/catalog/view_models/catalog_viewmodel.dart';
import '../ui/favorites/widgets/favorites_screen.dart';
import '../ui/hands_free_mode/widgets/hands_free_mode_screen.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/home/view_models/home_viewmodel.dart';
import '../ui/inventory/widgets/inventory_screen.dart';
import '../ui/recipe_details/widgets/recipe_details_screen.dart';
import '../ui/search/widgets/search_screen.dart';
import '../ui/search/view_models/search_viewmodel.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: Routes.home,
  // Rota inválida ou falha de navegação: volta para a home.
  onException: (context, state, router) => router.go(Routes.home),
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return MainShell(child: child);
      },
      routes: [
        GoRoute(
          path: Routes.home,
          builder: (context, state) {
            return ChangeNotifierProvider(
              create: (context) =>
                  HomeViewModel(repository: context.read<CatalogRepository>()),
              child: const HomeScreen(),
            );
          },
        ),
        GoRoute(
          path: Routes.aiRecipe,
          builder: (context, state) {
            return ChangeNotifierProvider(
              create: (context) =>
                  AiRecipesViewModel(repository: context.read<AiRepository>()),
              child: const AiRecipesScreen(),
            );
          },
        ),
        GoRoute(
          path: Routes.inventory,
          builder: (context, state) {
            return const InventoryScreen();
          },
        ),
        GoRoute(
          path: Routes.search,
          builder: (context, state) {
            return ChangeNotifierProvider(
              create: (context) => SearchViewModel(
                repository: context.read<CatalogRepository>(),
              ),
              child: const SearchScreen(),
            );
          },
        ),
        GoRoute(
          path: Routes.favorites,
          builder: (context, state) {
            return const FavoritesScreen();
          },
        ),
      ],
    ),
    GoRoute(
      path: Routes.catalog,
      builder: (context, state) {
        final type = state.uri.queryParameters['categoria'];
        return ChangeNotifierProvider(
          key: ValueKey(type),
          create: (context) => CatalogViewModel(
            repository: context.read<CatalogRepository>(),
            category: type == null ? null : RecipeCategory(type),
          ),
          child: const CatalogScreen(),
        );
      },
    ),
    GoRoute(
      path: Routes.recipes,
      redirect: (context, state) {
        if (state.uri.path == Routes.recipes) {
          return Routes.recipeDetails('1');
        }
        return null;
      },
      routes: [
        GoRoute(
          path: ':id',
          builder: (context, state) {
            return const RecipeDetailsScreen();
          },
          routes: [
            GoRoute(
              path: 'hands-free',
              builder: (context, state) {
                return const HandsFreeModeScreen();
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

class MainShell extends StatelessWidget {
  const MainShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      bottomNavigationBar: NavigationBar(
        selectedIndex: switch (location) {
          Routes.search => 1,
          Routes.favorites => 2,
          _ => 0,
        },
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go(Routes.home);
            case 1:
              context.go(Routes.search);
            case 2:
              context.go(Routes.favorites);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Buscar',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favoritos',
          ),
        ],
      ),
      body: child,
    );
  }
}
