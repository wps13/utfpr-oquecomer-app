import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/view_state.dart';
import '../view_models/hands_free_mode_viewmodel.dart';
import 'hands_free_recipe_steps.dart';

class HandsFreeModeBody extends StatelessWidget {
  const HandsFreeModeBody({required this.onExit, super.key});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HandsFreeModeViewModel>();
    if (vm.state == ViewState.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final Widget content;
    if (vm.state == ViewState.error) {
      content = LoadFeedback(
        title: vm.isNotFound
            ? 'Receita não encontrada'
            : 'Não foi possível abrir a receita',
        message: vm.loadError,
        onRetry: () => unawaited(vm.load()),
      );
    } else if (vm.steps.isEmpty) {
      content = LoadFeedback(
        title: 'Esta receita não tem passos de preparo',
        onRetry: onExit,
        actionLabel: 'Voltar',
        actionIcon: Icons.arrow_back,
      );
    } else {
      content = HandsFreeRecipeSteps(viewModel: vm, onExit: onExit);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: content,
        ),
      ),
    );
  }
}
