import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../data/services/voice/voice_capture_service.dart';
import '../../../domain/models/voice_command.dart';
import '../../../domain/models/voice_failure.dart';
import '../../../domain/voice/voice_command_interpreter.dart';

/// Escopo da tela. Não decide a navegação nem o passo atual da receita.
class VoiceCommandsViewModel extends ChangeNotifier
    with WidgetsBindingObserver {
  VoiceCommandsViewModel({
    required VoiceCaptureService capture,
    VoiceCommandInterpreter? interpreter,
  }) : _capture = capture,
       _interpreter = interpreter ?? VoiceCommandInterpreter() {
    _state = capture.state;
    _texts = capture.transcripts.listen(_onText);
    _errors = capture.failures.listen((failure) {
      if (_disposed) return;
      _failure = failure;
      notifyListeners();
    });
    _states = capture.states.listen((state) {
      if (_disposed) return;
      _state = state;
      if (state == VoiceCaptureState.listening) _failure = null;
      notifyListeners();
    });
    WidgetsBinding.instance.addObserver(this);
  }

  final VoiceCaptureService _capture;
  final VoiceCommandInterpreter _interpreter;
  final _commands = StreamController<VoiceCommand>.broadcast();
  late final StreamSubscription<String> _texts;
  late final StreamSubscription<VoiceFailure> _errors;
  late final StreamSubscription<VoiceCaptureState> _states;
  late VoiceCaptureState _state;
  VoiceFailure? _failure;
  bool _disposed = false;
  bool _enabled = false;

  Stream<VoiceCommand> get commands => _commands.stream;
  VoiceCaptureState get state => _state;
  VoiceFailure? get failure => _failure;

  Future<void> start() async {
    if (_disposed) return;
    _enabled = true;
    _failure = null;
    notifyListeners();
    await _capture.start();
  }

  Future<void> stop() {
    _enabled = false;
    return _capture.stop();
  }

  Future<T> duringPlayback<T>(Future<T> Function() playback) =>
      _capture.duringPlayback(playback);

  void _onText(String text) {
    if (_disposed || !_enabled) return;
    final command = _interpreter.interpret(text);
    if (command == null) return;
    _commands.add(command);
    if (command == VoiceCommand.exit || command == VoiceCommand.exitMode) {
      unawaited(stop());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive também ocorre durante um diálogo de permissão no iOS.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(stop());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _enabled = false;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_texts.cancel());
    unawaited(_errors.cancel());
    unawaited(_states.cancel());
    unawaited(_commands.close());
    unawaited(_capture.stop());
    super.dispose();
  }
}
