import 'dart:async';

import 'package:flutter/services.dart';

import '../../../domain/models/app_permission.dart';
import '../../../domain/models/voice_failure.dart';
import '../errors/error_reporter.dart';
import '../permissions/permission_service.dart';
import 'voice_capture_service.dart';
import 'voice_recognition_engine.dart';

/// Uma instância por app: o plugin conserva os callbacks de initialize.
class DeviceVoiceCaptureService implements VoiceCaptureService {
  DeviceVoiceCaptureService({
    required VoiceRecognitionEngine engine,
    required PermissionService permissions,
    required ErrorReporter errorReporter,
    Duration restartDelay = const Duration(milliseconds: 400),
    Duration finalResultWait = const Duration(seconds: 3),
    Duration startTimeout = const Duration(seconds: 5),
  })
    // ignore: prefer_initializing_formals
    : _engine = engine,
       // ignore: prefer_initializing_formals
       _permissions = permissions,
       _reporter = errorReporter,
       // ignore: prefer_initializing_formals
       _restartDelay = restartDelay,
       // ignore: prefer_initializing_formals
       _finalResultWait = finalResultWait,
       // ignore: prefer_initializing_formals
       _startTimeout = startTimeout;

  final VoiceRecognitionEngine _engine;
  final PermissionService _permissions;
  final ErrorReporter _reporter;
  final Duration _restartDelay;
  final Duration _finalResultWait;
  final Duration _startTimeout;
  final _transcripts = StreamController<String>.broadcast();
  final _failures = StreamController<VoiceFailure>.broadcast();
  final _states = StreamController<VoiceCaptureState>.broadcast();
  Future<void> _pending = Future<void>.value();
  Future<void>? _disposing;
  Timer? _restartTimer;
  Timer? _startTimer;
  VoiceCaptureState _state = VoiceCaptureState.stopped;
  bool _wanted = false;
  bool _disposed = false;
  bool _ready = false;
  bool _acceptEvents = false;
  bool _delivered = false;
  int _epoch = 0;
  int _session = 0;
  int _playbacks = 0;
  int _engineRetries = 0;
  String? _locale;

  @override
  Stream<String> get transcripts => _transcripts.stream;
  @override
  Stream<VoiceFailure> get failures => _failures.stream;
  @override
  Stream<VoiceCaptureState> get states => _states.stream;
  @override
  VoiceCaptureState get state => _state;

  bool _current(int epoch) => !_disposed && _wanted && epoch == _epoch;
  bool get _canListen => !_disposed && _wanted && _playbacks == 0;

  void _setState(VoiceCaptureState value) {
    if (_disposed || value == _state) return;
    _state = value;
    _states.add(value);
  }

  void _cancelTimers() {
    _restartTimer?.cancel();
    _startTimer?.cancel();
  }

  // Serializa initialize/listen/cancel sem deixar uma falha quebrar a fila.
  Future<void> _enqueue(Future<void> Function() action, {int? epoch}) {
    _pending = _pending.then((_) async {
      try {
        await action();
      } on VoiceFailure catch (failure) {
        if (epoch != null && !_current(epoch)) return;
        await _fail(failure);
      } on MissingPluginException {
        if (epoch != null && !_current(epoch)) return;
        await _fail(
          const VoiceFailure(VoiceFailureKind.recognitionUnavailable),
        );
      } on TimeoutException {
        if (epoch != null && !_current(epoch)) return;
        await _fail(const VoiceFailure(VoiceFailureKind.engine));
      } on Object {
        if (epoch != null && !_current(epoch)) return;
        await _reportUnexpected();
        await _fail(const VoiceFailure(VoiceFailureKind.unexpected));
      }
    });
    return _pending;
  }

  @override
  Future<void> start() {
    if (_disposed || _wanted) return _pending;
    _wanted = true;
    _engineRetries = 0;
    final epoch = ++_epoch;
    _setState(VoiceCaptureState.starting);
    return _enqueue(() async {
      await _authorize(
        AppPermission.microphone,
        VoiceFailureKind.microphoneDenied,
        epoch,
      );
      if (!_current(epoch)) return;
      await _authorize(
        AppPermission.speechRecognition,
        VoiceFailureKind.speechPermissionDenied,
        epoch,
      );
      if (!_current(epoch)) return;
      if (!_ready) {
        _ready = await _engine
            .initialize(onStatus: _onStatus, onError: _onError)
            .timeout(_startTimeout);
        if (!_current(epoch)) return;
        if (!_ready) {
          throw const VoiceFailure(VoiceFailureKind.recognitionUnavailable);
        }
      }
      final locales = await _engine.locales().timeout(_startTimeout);
      if (!_current(epoch)) return;
      _locale = locales
          .where(
            (locale) => locale.replaceAll('_', '-').toLowerCase() == 'pt-br',
          )
          .firstOrNull;
      if (_locale == null) {
        throw const VoiceFailure(VoiceFailureKind.languageUnavailable);
      }
      if (_playbacks > 0) {
        _setState(VoiceCaptureState.suspended);
      } else {
        await _listen(epoch);
      }
    }, epoch: epoch);
  }

  Future<void> _authorize(
    AppPermission permission,
    VoiceFailureKind kind,
    int epoch,
  ) async {
    var access = await _permissions.check(permission);
    if (!_current(epoch)) return;
    if (access == PermissionAccess.denied) {
      access = await _permissions.request(permission);
    }
    if (!_current(epoch)) return;
    if (!access.isAuthorized) {
      throw VoiceFailure(kind, permissionAccess: access);
    }
  }

  Future<void> _cancelEngine() async {
    _acceptEvents = false;
    _session++;
    if (_ready) await _engine.cancel().timeout(_startTimeout);
  }

  Future<void> _listen(int epoch) async {
    if (!_current(epoch) || !_canListen) return;
    await _cancelEngine();
    if (!_current(epoch) || !_canListen) return;
    final session = ++_session;
    _acceptEvents = true;
    _delivered = false;
    _setState(VoiceCaptureState.starting);
    // Alguns motores devolvem listen() sem iniciar nem emitir erro.
    _startTimer = Timer(_startTimeout, () => _onError('error_client'));
    await _engine
        .listen(
          localeId: _locale!,
          onResult: (text, {required isFinal}) {
            if (!_canListen ||
                !_acceptEvents ||
                session != _session ||
                !isFinal ||
                _delivered ||
                text.trim().isEmpty) {
              return;
            }
            _delivered = true;
            _engineRetries = 0;
            _transcripts.add(text);
            // Rearme após a frase final, mesmo se o motor ainda não avisou
            // que encerrou. Saída e leitura podem cancelar este reinício.
            _acceptEvents = false;
            _scheduleRestart(_restartDelay);
          },
        )
        .timeout(_startTimeout);
  }

  void _onStatus(VoiceEngineStatus status) {
    if (!_canListen || !_acceptEvents) return;
    switch (status) {
      case VoiceEngineStatus.listening:
        _startTimer?.cancel();
        _setState(VoiceCaptureState.listening);
      case VoiceEngineStatus.notListening:
      case VoiceEngineStatus.done:
        // Android pode enviar done antes do erro ou do último resultado.
        // Preserve a janela de entrega, inclusive para não perder erros reais.
        _startTimer?.cancel();
        _scheduleRestart(_finalResultWait, reportSilence: true);
    }
  }

  void _scheduleRestart(Duration delay, {bool reportSilence = false}) {
    if (!_canListen) return;
    _restartTimer?.cancel();
    _setState(VoiceCaptureState.restarting);
    final epoch = _epoch;
    _restartTimer = Timer(delay, () {
      if (_current(epoch) && _canListen) {
        if (reportSilence && !_delivered) {
          _failures.add(const VoiceFailure(VoiceFailureKind.noSpeech));
        }
        unawaited(_enqueue(() => _listen(epoch), epoch: epoch));
      }
    });
  }

  void _onError(String code) {
    if (!_canListen || !_acceptEvents) return;
    _acceptEvents = false;
    _cancelTimers();
    if (code == 'error_no_match' || code == 'error_speech_timeout') {
      _restartAfterSilence();
      return;
    }
    if (const {
      'error_audio_error',
      'error_client',
      'error_network',
      'error_network_timeout',
      'error_busy',
      'error_server',
      'error_server_disconnected',
      'error_retry',
      'error_too_many_requests',
    }.contains(code)) {
      _failures.add(const VoiceFailure(VoiceFailureKind.engine));
      if (++_engineRetries <= 3) {
        _scheduleRestart(_restartDelay * _engineRetries);
      } else {
        _deactivate();
        _setState(VoiceCaptureState.failed);
        unawaited(_enqueue(_cancelEngine));
      }
      return;
    }
    final failure = VoiceFailure(switch (code) {
      'error_permission' => VoiceFailureKind.microphoneDenied,
      'error_language_not_supported' ||
      'error_language_unavailable' => VoiceFailureKind.languageUnavailable,
      'error_speech_recognizer_disabled' =>
        VoiceFailureKind.recognitionUnavailable,
      _ => VoiceFailureKind.unexpected,
    });
    _deactivate();
    _failures.add(failure);
    _setState(VoiceCaptureState.failed);
    unawaited(
      _enqueue(() async {
        if (failure.kind == VoiceFailureKind.unexpected) {
          await _reportUnexpected();
        }
        await _cancelEngine();
      }),
    );
  }

  void _restartAfterSilence() {
    _engineRetries = 0;
    _failures.add(const VoiceFailure(VoiceFailureKind.noSpeech));
    // Um intervalo fixo evita aumentar as janelas sem escuta após silêncio.
    _scheduleRestart(_restartDelay);
  }

  void _deactivate() {
    _wanted = false;
    _epoch++;
    _acceptEvents = false;
    _cancelTimers();
  }

  Future<void> _fail(VoiceFailure failure) async {
    _deactivate();
    if (!_disposed) {
      _failures.add(failure);
      _setState(VoiceCaptureState.failed);
    }
    try {
      await _cancelEngine();
    } on Object {
      await _reportUnexpected();
    }
  }

  Future<void> _reportUnexpected() async {
    try {
      await _reporter.recordError(
        StateError('Falha inesperada na captura de comandos de voz'),
        StackTrace.current,
        reason: 'voice_capture',
      );
    } on Object {
      // Uma falha no relatório não pode interromper o fluxo de voz.
    }
  }

  @override
  Future<void> stop() {
    _deactivate();
    _setState(VoiceCaptureState.stopped);
    return _enqueue(_cancelEngine);
  }

  @override
  Future<T> duringPlayback<T>(Future<T> Function() playback) async {
    if (_disposed) {
      throw const VoiceFailure(VoiceFailureKind.recognitionUnavailable);
    }
    _playbacks++;
    _acceptEvents = false;
    _cancelTimers();
    var cancelled = false;
    try {
      await _enqueue(() async {
        await _cancelEngine();
        cancelled = true;
        if (_wanted) _setState(VoiceCaptureState.suspended);
      });
      // Não toque áudio se não foi possível desligar a captura.
      if (!cancelled || _disposed) {
        throw const VoiceFailure(VoiceFailureKind.engine);
      }
      return await playback();
    } finally {
      _playbacks--;
      if (_canListen && _ready && _locale != null) {
        final epoch = _epoch;
        await _enqueue(() => _listen(epoch), epoch: epoch);
      }
    }
  }

  @override
  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _deactivate();
    _setState(VoiceCaptureState.stopped);
    _disposed = true;
    return _disposing = _enqueue(() async {
      try {
        await _cancelEngine();
      } finally {
        // Uma assinatura pausada não pode bloquear o descarte do microfone.
        unawaited(_transcripts.close());
        unawaited(_failures.close());
        unawaited(_states.close());
      }
    });
  }
}
