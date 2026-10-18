import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/env.dart';
import 'data/repositories/favorites_repository.dart';
import 'data/services/api/api_client.dart';
import 'data/services/crash/error_reporter.dart';
import 'ui/core/themes/theme.dart';
import 'ui/favorites/view_models/favorites_viewmodel.dart';
import 'ui/favorites/widgets/favorites_screen.dart';

void main() {
  const ErrorReporter reporter = DebugErrorReporter();

  // Erros inesperados do framework e assíncronos vão para o reporter.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(reporter.report(details.exception, details.stack, fatal: true));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reporter.report(error, stack, fatal: true));
    return true;
  };

  final env = Env.fromEnvironment();

  runApp(
    MultiProvider(
      // Providers globais (repositórios, serviços) ficam acima do MaterialApp.
      providers: [
        Provider<Env>.value(value: env),
        Provider<ErrorReporter>.value(value: reporter),
        Provider<CatalogApiClient>(
          create: (c) => CatalogApiClient(env, c.read<ErrorReporter>()),
        ),
        Provider<GeminiApiClient>(
          create: (c) => GeminiApiClient(env, c.read<ErrorReporter>()),
        ),
        Provider<FavoritesRepository>(
          create: (_) => InMemoryFavoritesRepository(),
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
    return MaterialApp(
      theme: AppTheme.light,
      home: ChangeNotifierProvider(
        // A ViewModel é criada aqui, nunca dentro de um build de tela.
        create: (c) =>
            FavoritesViewModel(repository: c.read<FavoritesRepository>()),
        child: const FavoritesScreen(),
      ),
    );
  }
}