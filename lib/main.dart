import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/repositories/favorites_repository.dart';
import 'ui/favorites/view_models/favorites_viewmodel.dart';
import 'ui/favorites/widgets/favorites_screen.dart';

void main() {
  runApp(
    MultiProvider(
      // Providers globais (repositórios, serviços) ficam acima do MaterialApp.
      providers: [
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
      home: ChangeNotifierProvider(
        // A ViewModel é criada aqui, nunca dentro de um build de tela.
        create: (c) =>
            FavoritesViewModel(repository: c.read<FavoritesRepository>()),
        child: const FavoritesScreen(),
      ),
    );
  }
}
