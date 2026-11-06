import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'routes.dart';
import 'route_observer.dart';
import '../data/services/errors/error_reporter.dart';
import '../data/services/permissions/permission_service.dart';
import '../data/repositories/ai_repository.dart';
import '../data/repositories/favorites_repository.dart';
import '../data/repositories/pantry_repository.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/services/speech/speech_service.dart';
import '../domain/models/recipe_category.dart';
import '../ui/ai_recipes/widgets/ai_recipes_screen.dart';
import '../ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';

import '../ui/catalog/widgets/catalog_screen.dart';
import '../ui/catalog/view_models/catalog_viewmodel.dart';
import '../ui/favorites/widgets/favorites_screen.dart';
import '../ui/hands_free_mode/widgets/hands_free_mode_screen.dart';
import '../ui/hands_free_mode/view_models/hands_free_mode_viewmodel.dart';
import '../data/services/voice/voice_capture_service.dart';
import '../data/services/screen_wake_lock/screen_wake_lock_service.dart';
import '../ui/home/widgets/home_screen.dart';
import '../ui/home/view_models/home_viewmodel.dart';
import '../ui/inventory/widgets/inventory_screen.dart';
import '../ui/inventory/view_models/inventory_viewmodel.dart';
import '../ui/recipe_details/view_models/recipe_details_viewmodel.dart';
import '../ui/recipe_details/widgets/recipe_details_screen.dart';
import '../ui/search/widgets/search_screen.dart';
import '../ui/search/view_models/search_viewmodel.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [appRouteObserver],
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
              create: (context) => AiRecipesViewModel(
                repository: context.read<AiRepository>(),
                pantryRepository: context.read<PantryRepository>(),
              ),
              child: const AiRecipesScreen(),
            );
          },
        ),
        GoRoute(
          path: Routes.inventory,
          builder: (context, state) {
            return ChangeNotifierProvider(
              create: (context) => InventoryViewModel(
                repository: context.read<PantryRepository>(),
              ),
              child: const InventoryScreen(),
            );
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
            final id = state.pathParameters['id']!;
            return ChangeNotifierProvider(
              key: ValueKey(id),
              create: (context) => RecipeDetailsViewModel(
                recipeId: id,
                catalogRepository: context.read<CatalogRepository>(),
                favoritesRepository: context.read<FavoritesRepository>(),
              ),
              child: const RecipeDetailsScreen(),
            );
          },
          routes: [
            GoRoute(
              path: 'hands-free',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return ChangeNotifierProvider(
                  key: ValueKey(id),
                  create: (context) => HandsFreeModeViewModel(
                    recipeId: id,
                    catalogRepository: context.read<CatalogRepository>(),
                    favoritesRepository: context.read<FavoritesRepository>(),
                    capture: context.read<VoiceCaptureService>(),
                    wakeLock: context.read<ScreenWakeLockService>(),
                    speechService: context.read<SpeechService>(),
                    permissions: context.read<PermissionService>(),
                    errorReporter: context.read<ErrorReporter>(),
                  ),
                  child: const HandsFreeModeScreen(),
                );
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
