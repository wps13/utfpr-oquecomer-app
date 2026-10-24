import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'routing/router.dart';

import 'config/ai_dependencies.dart';
import 'config/env.dart';
import 'config/error_handling.dart';
import 'config/firebase_bootstrap.dart';
import 'data/repositories/ai_repository.dart';
import 'data/repositories/api_catalog_repository.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/services/api/api_client.dart';
import 'data/services/crash/error_reporter.dart' as http_errors;
import 'data/services/errors/error_reporter.dart';
import 'data/services/errors/http_error_reporter.dart';
import 'data/services/permissions/permission_handler_service.dart';
import 'data/services/permissions/permission_service.dart';
import 'ui/core/themes/theme.dart';
import 'ui/favorites/view_models/favorites_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final favoritesBox = await Hive.openBox<dynamic>('favorites');
  final errorReporter = await initializeErrorReporting();
  installErrorHandlers(errorReporter: errorReporter);
  final env = Env.fromEnvironment();

  runApp(
    MultiProvider(
      // Providers globais (repositórios, serviços) ficam acima do MaterialApp.
      providers: [
        Provider<Env>.value(value: env),
        Provider<ErrorReporter>.value(value: errorReporter),
        Provider<http_errors.ErrorReporter>(
          create: (c) =>
              HttpErrorReporter(errorReporter: c.read<ErrorReporter>()),
        ),
        Provider<PermissionService>(create: (_) => PermissionHandlerService()),
        Provider<CatalogApiClient>(
          create: (c) =>
              CatalogApiClient(env, c.read<http_errors.ErrorReporter>()),
          dispose: (_, client) => client.close(),
        ),
        Provider<CatalogRepository>(
          create: (c) => ApiCatalogRepository(
            client: c.read<CatalogApiClient>(),
            errorReporter: c.read<ErrorReporter>(),
          ),
        ),
        Provider<GeminiApiClient>(
          create: (c) =>
              GeminiApiClient(env, c.read<http_errors.ErrorReporter>()),
        ),
        Provider<AiDependencies>(
          create: (c) => AiDependencies(errorReporter: c.read<ErrorReporter>()),
          dispose: (_, dependencies) => dependencies.close(),
        ),
        Provider<AiRepository>(
          create: (c) => c.read<AiDependencies>().repository,
        ),
        Provider<FavoritesRepository>(
          create: (c) => HiveFavoritesRepository(
            box: HiveFavoritesBoxAdapter(favoritesBox),
            errorReporter: c.read<ErrorReporter>(),
          ),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // A ViewModel é criada aqui, nunca dentro de um build de tela.
      create: (c) =>
          FavoritesViewModel(repository: c.read<FavoritesRepository>()),
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }
}
