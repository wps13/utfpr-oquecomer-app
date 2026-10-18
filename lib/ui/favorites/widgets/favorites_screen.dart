import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/view_state.dart';
import '../view_models/favorites_viewmodel.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // Estado efêmero de UI: fica no widget, não na ViewModel.
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(context.read<FavoritesViewModel>().load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    _controller.clear();
    unawaited(context.read<FavoritesViewModel>().add(name));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Favoritos')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Novo favorito',
                      ),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(onPressed: _add, icon: const Icon(Icons.add)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _Body(vm: vm)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});

  final FavoritesViewModel vm;

  @override
  Widget build(BuildContext context) {
    switch (vm.state) {
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro: ${vm.errorMessage}'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: context.read<FavoritesViewModel>().load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
      case ViewState.success:
        if (vm.favorites.isEmpty) {
          return const Center(child: Text('Nenhum favorito ainda'));
        }
        return ListView(
          children: [
            for (final f in vm.favorites)
              ListTile(
                title: Text(f.name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () =>
                      context.read<FavoritesViewModel>().remove(f.id),
                ),
              ),
          ],
        );
    }
  }
}
