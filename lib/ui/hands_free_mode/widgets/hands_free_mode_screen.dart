import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../data/services/voice/voice_capture_service.dart';
import '../../../routing/route_observer.dart';
import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/view_state.dart';
import '../view_models/hands_free_mode_viewmodel.dart';

class HandsFreeModeScreen extends StatefulWidget {
  const HandsFreeModeScreen({super.key});

  @override
  State<HandsFreeModeScreen> createState() => _HandsFreeModeScreenState();
}

class _HandsFreeModeScreenState extends State<HandsFreeModeScreen>
    with RouteAware {
  late final HandsFreeModeViewModel _viewModel;
  bool _leaving = false;
  bool _didNavigate = false;

  @override
  void initState() {
    super.initState();
    _viewModel = context.read<HandsFreeModeViewModel>();
    _viewModel.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_viewModel.load());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => _viewModel.setVisible(visible: false);

  @override
  void didPop() => _viewModel.setVisible(visible: false);

  @override
  void didPopNext() => _viewModel.setVisible(visible: true);

  void _onChange() {
    if (!_viewModel.exitRequested || _leaving) return;
    _leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _leave();
    });
  }

  void _leave() {
    if (_didNavigate) return;
    _didNavigate = true;
    unawaited(_viewModel.suspend());
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _viewModel.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HandsFreeModeViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo mãos livres'),
        leading: BackButton(onPressed: _leave),
      ),
      body: SafeArea(
        child: vm.state == ViewState.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: vm.state == ViewState.error
                        ? LoadFeedback(
                            title: vm.isNotFound
                                ? 'Receita não encontrada'
                                : 'Não foi possível abrir a receita',
                            message: vm.loadError,
                            onRetry: () => unawaited(vm.load()),
                          )
                        : vm.steps.isEmpty
                        ? LoadFeedback(
                            title: 'Esta receita não tem passos de preparo',
                            onRetry: _leave,
                            actionLabel: 'Voltar',
                            actionIcon: Icons.arrow_back,
                          )
                        : _RecipeSteps(viewModel: vm, onExit: _leave),
                  ),
                ),
              ),
      ),
    );
  }
}

class _RecipeSteps extends StatelessWidget {
  const _RecipeSteps({required this.viewModel, required this.onExit});

  final HandsFreeModeViewModel viewModel;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(vm.recipeTitle, style: theme.textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.x4),
        _VoiceStatus(viewModel: vm),
        const SizedBox(height: AppSpacing.x4),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Passo ${vm.stepIndex + 1} de ${vm.steps.length}',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.x3),
                LinearProgressIndicator(
                  value: (vm.stepIndex + 1) / vm.steps.length,
                  semanticsLabel: 'Progresso dos passos',
                ),
                const SizedBox(height: AppSpacing.x6),
                Text(vm.currentStep, style: theme.textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.x6),
                FilledButton.icon(
                  onPressed: () => unawaited(
                    vm.isReading ? vm.pauseReading() : vm.readStep(),
                  ),
                  icon: Icon(vm.isReading ? Icons.pause : Icons.volume_up),
                  label: Text(vm.isReading ? 'Pausar leitura' : 'Ouvir passo'),
                ),
                const SizedBox(height: AppSpacing.x3),
                Wrap(
                  spacing: AppSpacing.x3,
                  runSpacing: AppSpacing.x3,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    OutlinedButton.icon(
                      onPressed: vm.hasPrevious
                          ? () => unawaited(vm.previousStep())
                          : null,
                      icon: const Icon(Icons.skip_previous),
                      label: const Text('Passo anterior'),
                    ),
                    OutlinedButton.icon(
                      onPressed: vm.hasNext
                          ? () => unawaited(vm.nextStep())
                          : null,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('Próximo passo'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (vm.feedback != null || vm.readingError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x3),
            child: Text(
              vm.readingError ?? vm.feedback!,
              semanticsLabel: vm.readingError ?? vm.feedback,
              style: TextStyle(
                color: vm.readingError == null ? null : theme.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.x4),
        const ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text('Comandos de voz'),
          children: [
            Padding(
              padding: EdgeInsets.only(bottom: AppSpacing.x4),
              child: Text(
                '“Continuar” lê o passo desde o início. '
                '“Parar” pausa a leitura. “Próximo passo” e “passo anterior” '
                'mudam o passo. “Sair” ou “sair do modo” encerram o modo.\n\n'
                'Fale quando o indicador mostrar “Ouvindo”. Durante a leitura, '
                'use o botão para pausar; a escuta volta ao final.',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x3),
        TextButton.icon(
          onPressed: onExit,
          icon: const Icon(Icons.close),
          label: const Text('Sair do modo'),
        ),
      ],
    );
  }
}

class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus({required this.viewModel});
  final HandsFreeModeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final vm = viewModel;
    final failure = vm.voiceFailure;
    final colors = Theme.of(context).colorScheme;
    final listening =
        vm.voiceState == VoiceCaptureState.listening &&
        vm.voiceEnabled &&
        !vm.isReading;
    final title = vm.isReading
        ? 'Lendo o passo'
        : !vm.voiceEnabled
        ? 'Comandos de voz desativados'
        : switch (vm.voiceState) {
            VoiceCaptureState.listening => 'Ouvindo',
            VoiceCaptureState.starting => 'Preparando o microfone',
            VoiceCaptureState.restarting => 'Retomando a escuta',
            VoiceCaptureState.suspended => 'Escuta pausada',
            VoiceCaptureState.failed => 'Modo por voz indisponível',
            VoiceCaptureState.stopped => 'Microfone desligado',
          };
    return Semantics(
      liveRegion: true,
      child: Card(
        margin: EdgeInsets.zero,
        color: listening ? colors.tertiaryContainer : colors.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    vm.isReading
                        ? Icons.volume_up
                        : listening
                        ? Icons.mic
                        : Icons.mic_off,
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                vm.isReading
                    ? 'A escuta volta automaticamente ao terminar a leitura.'
                    : failure?.message ??
                          'Diga “continuar” para ouvir o passo '
                              'ou “próximo passo” para avançar.',
              ),
              if (failure != null || !vm.voiceEnabled)
                Wrap(
                  spacing: AppSpacing.x2,
                  children: [
                    TextButton.icon(
                      onPressed: () => unawaited(vm.startVoice()),
                      icon: const Icon(Icons.mic),
                      label: const Text('Ativar comandos de voz'),
                    ),
                    if (failure?.canOpenSettings == true)
                      TextButton.icon(
                        onPressed: () => unawaited(vm.openSettings()),
                        icon: const Icon(Icons.settings),
                        label: const Text('Abrir configurações'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
