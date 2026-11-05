// Dependências privadas com parâmetros nomeados públicos.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../data/services/errors/error_reporter.dart';
import '../../../data/services/permissions/permission_service.dart';
import '../../../data/services/speech/speech_service.dart';
import '../../../data/services/voice/voice_capture_service.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/speech_status.dart';
import '../../../domain/models/voice_command.dart';
import '../../../domain/models/voice_failure.dart';
import '../../core/view_state.dart';
import '../../recipe_details/view_models/recipe_details_viewmodel.dart';
import 'voice_commands_viewmodel.dart';

/// Coordena o passo atual, a leitura e a escuta somente enquanto a tela está
/// visível. Não conhece o Navigator e não persiste alterações na receita.
class HandsFreeModeViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  HandsFreeModeViewModel({
    required String recipeId,
    required CatalogRepository catalogRepository,
    required FavoritesRepository favoritesRepository,
    required VoiceCaptureService capture,
    required SpeechService speechService,
    required PermissionService permissions,
    required ErrorReporter errorReporter,
  }) : _details = RecipeDetailsViewModel(
         recipeId: recipeId,
         catalogRepository: catalogRepository,
         favoritesRepository: favoritesRepository,
       ),
       _voice = VoiceCommandsViewModel(capture: capture),
       _speech = speechService,
       _permissions = permissions,
       _errorReporter = errorReporter {
    _details.addListener(_changed);
    _voice.addListener(_changed);
    _speech.status.addListener(_onSpeechStatus);
    _commands = _voice.commands.listen(_onCommand);
    WidgetsBinding.instance.addObserver(this);
  }

  final RecipeDetailsViewModel _details;
  final VoiceCommandsViewModel _voice;
  final SpeechService _speech;
  final PermissionService _permissions;
  final ErrorReporter _errorReporter;
  late final StreamSubscription<VoiceCommand> _commands;
  _Reading? _reading;
  final _readings = <_Reading>{};
  int _audioAction = 0;
  int _load = 0;
  int _stepIndex = 0;
  bool _disposed = false;
  bool _visible = true;
  bool _foreground = true;
  bool _voiceWanted = false;
  bool _exitRequested = false;
  String? _feedback;
  String? _readingError;

  ViewState get state => _details.state;
  String get recipeTitle => _details.recipe?.title ?? 'Receita';
  String? get loadError => _details.errorMessage;
  bool get isNotFound => _details.isNotFound;
  List<String> get steps => _details.steps;
  int get stepIndex => _stepIndex;
  String get currentStep => steps.isEmpty ? '' : steps[_stepIndex];
  bool get hasPrevious => _stepIndex > 0;
  bool get hasNext => _stepIndex + 1 < steps.length;
  bool get isReading => _reading != null;
  bool get exitRequested => _exitRequested;
  String? get feedback => _feedback;
  String? get readingError => _readingError;
  VoiceCaptureState get voiceState => _voice.state;
  VoiceFailure? get voiceFailure => _voice.failure;
  bool get voiceEnabled => _voiceWanted;
  bool get _available =>
      !_disposed && _visible && _foreground && !_exitRequested;
  bool get _ready =>
      _available && state == ViewState.success && steps.isNotEmpty;

  /// A entrada na tela vem do botão Iniciar do modo cozinha. Não solicita
  /// microfone durante a abertura do app ou de uma receita comum.
  Future<void> load() async {
    final request = ++_load;
    await suspend();
    if (!_available) return;
    _stepIndex = 0;
    await _details.load();
    if (request == _load && _ready) await startVoice();
  }

  Future<void> startVoice() async {
    if (!_ready) return;
    _voiceWanted = true;
    _feedback = null;
    _changed();
    await _voice.start();
  }

  void _onCommand(VoiceCommand command) {
    if (!_ready || !_voiceWanted || isReading) return;
    switch (command) {
      case VoiceCommand.resume:
        unawaited(readStep());
      case VoiceCommand.pause:
        unawaited(pauseReading());
      case VoiceCommand.nextStep:
        unawaited(nextStep());
      case VoiceCommand.previousStep:
        unawaited(previousStep());
      case VoiceCommand.exit:
      case VoiceCommand.exitMode:
        exit();
    }
  }

  Future<void> nextStep() async {
    if (!_ready) return;
    if (!hasNext) {
      _feedback = 'Você já está no último passo.';
      _changed();
      return;
    }
    _stepIndex++;
    await readStep();
  }

  Future<void> previousStep() async {
    if (!_ready) return;
    if (!hasPrevious) {
      _feedback = 'Você já está no primeiro passo.';
      _changed();
      return;
    }
    _stepIndex--;
    await readStep();
  }

  /// speak() confirma apenas o início. Mantemos a captura suspensa até a
  /// mudança de status que confirma o fim real da leitura, ou seu cancelamento.
  Future<void> readStep() async {
    if (!_ready) return;
    final action = ++_audioAction;
    final reading = _Reading();
    final text = currentStep;
    _reading = reading;
    _readings.add(reading);
    _readingError = null;
    _feedback = null;
    _changed();
    try {
      await _voice.duringPlayback(() async {
        // Adquire a nova suspensão antes de liberar uma leitura anterior.
        if (!_available || action != _audioAction) return;
        _finishReadings(except: reading);
        await _speech.stop();
        if (!_available || action != _audioAction) return;
        try {
          await Future.any<void>([_speech.speak(text), reading.done.future]);
          if (!_available || action != _audioAction) return;
          reading.started = true;
          if (_speech.status.value != SpeechStatus.speaking) reading.finish();
          await reading.done.future;
        } on Object {
          // Ainda dentro da suspensão: não religue o microfone com áudio.
          await _speech.stop();
          rethrow;
        }
      });
    } on VoiceFailure catch (failure) {
      if (action == _audioAction) _readingError = failure.message;
    } on SpeechFailure catch (failure) {
      if (action == _audioAction) _readingError = failure.message;
    } on Object catch (_, stack) {
      if (action == _audioAction) {
        _readingError = 'Não foi possível ler o passo. Tente novamente.';
      }
      _reportUnexpected(stack, 'Falha inesperada na leitura do passo');
    } finally {
      reading.finish();
      _readings.remove(reading);
      if (identical(_reading, reading)) {
        _reading = null;
        _changed();
      }
    }
  }

  void _finishReadings({_Reading? except}) {
    for (final reading in _readings) {
      if (!identical(reading, except)) reading.finish();
    }
  }

  void _onSpeechStatus() {
    final reading = _reading;
    if (reading != null &&
        reading.started &&
        _speech.status.value != SpeechStatus.speaking) {
      reading.finish();
    }
  }

  /// A retomada relê o passo desde o início, conforme o contrato da APP-42.
  Future<void> pauseReading() async {
    if (!_ready) return;
    final action = ++_audioAction;
    try {
      await _voice.duringPlayback(() async {
        if (!_available || action != _audioAction) return;
        _reading = null;
        _finishReadings();
        // stop também cancela uma inicialização do motor ainda pendente.
        await _speech.stop();
        if (!_available || action != _audioAction) return;
        _feedback = 'Leitura pausada. Diga “continuar” para reler este passo.';
        _changed();
      });
    } on VoiceFailure catch (failure) {
      if (action == _audioAction) _readingError = failure.message;
      _changed();
    } on Object catch (_, stack) {
      if (action == _audioAction) {
        _readingError = 'Não foi possível pausar a leitura. Tente novamente.';
      }
      _reportUnexpected(stack, 'Falha inesperada ao pausar a leitura');
      _changed();
    }
  }

  Future<void> openSettings() async {
    await suspend();
    try {
      if (!await _permissions.openSettings()) {
        _feedback = 'Não foi possível abrir os ajustes do dispositivo.';
        _changed();
      }
    } on Object catch (_, stack) {
      _feedback = 'Não foi possível abrir os ajustes do dispositivo.';
      _reportUnexpected(stack, 'Falha ao abrir ajustes de permissões');
      _changed();
    }
  }

  void exit() {
    if (_disposed || _exitRequested) return;
    _exitRequested = true;
    unawaited(suspend());
    _changed();
  }

  /// Interrompe a escuta antes de liberar a suspensão da leitura. Assim,
  /// sair, bloquear a tela ou abrir outra rota nunca reativa o microfone.
  Future<void> suspend() {
    ++_audioAction;
    _voiceWanted = false;
    final stopped = _voice.stop();
    _finishReadings();
    _reading = null;
    final silence = _speech.stop();
    _changed();
    return Future.wait([stopped, silence]);
  }

  void setVisible({required bool visible}) {
    _visible = visible;
    if (!visible) unawaited(suspend());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      unawaited(suspend());
    }
  }

  void _reportUnexpected(StackTrace stack, String reason) {
    // Não envia a receita, transcrições ou mensagens nativas ao Crashlytics.
    unawaited(
      _errorReporter
          .recordError(StateError(reason), stack, reason: reason)
          .catchError((Object _) {}),
    );
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _speech.status.removeListener(_onSpeechStatus);
    _details.removeListener(_changed);
    _voice.removeListener(_changed);
    unawaited(_commands.cancel());
    // stop() da captura é síncrono na intenção, antes de liberar a leitura.
    unawaited(suspend());
    _voice.dispose();
    _details.dispose();
    super.dispose();
  }
}

class _Reading {
  final done = Completer<void>();
  bool started = false;

  void finish() {
    if (!done.isCompleted) done.complete();
  }
}
