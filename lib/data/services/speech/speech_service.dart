import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/speech_status.dart';

/// Leitura em voz alta, injetável nas ViewModels. Falhas são lançadas como
/// [SpeechFailure]; [pause] e [stop] nunca lançam.
abstract interface class SpeechService {
  ValueListenable<SpeechStatus> get status;

  /// Interrompe a leitura atual, se houver, e lê [text] desde o início.
  Future<void> speak(String text);

  /// Interrompe a leitura sem descartá-la da tela. Um novo [speak] recomeça
  /// o texto, pois a retomada não é igual no Android e no iOS.
  Future<void> pause();

  Future<void> stop();
}

class SpeechConfig {
  const SpeechConfig({
    this.language = 'pt-BR',
    this.speechRate = 0.5,
    this.pitch = 1.0,
  });

  final String language;

  /// 0.5 corresponde à velocidade normal no Android e no iOS.
  final double speechRate;
  final double pitch;
}

enum TtsEvent { start, completion, error }

/// Adaptador do motor de voz nativo, substituído por um falso nos testes.
abstract interface class TtsEngine {
  void setEventHandler(void Function(TtsEvent event) handler);

  /// Prepara o motor e informa se existe um motor de voz no aparelho.
  Future<bool> initialize();
  Future<bool> setLanguage(String language);
  Future<void> setSpeechRate(double rate);
  Future<void> setPitch(double pitch);
  Future<bool> speak(String text);
  Future<bool> pause();
  Future<void> stop();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine({TargetPlatform? platform})
    : _platform = platform ?? defaultTargetPlatform;

  final TargetPlatform _platform;
  void Function(TtsEvent event)? _onEvent;
  FlutterTts? _plugin;
  bool _initializedBefore = false;

  // O plugin só é criado quando a leitura é usada pela primeira vez.
  FlutterTts get _tts => _plugin ??= FlutterTts()
    ..setStartHandler(() => _onEvent?.call(TtsEvent.start))
    ..setContinueHandler(() => _onEvent?.call(TtsEvent.start))
    ..setCompletionHandler(() => _onEvent?.call(TtsEvent.completion))
    ..setErrorHandler((_) => _onEvent?.call(TtsEvent.error));

  @override
  void setEventHandler(void Function(TtsEvent event) handler) =>
      _onEvent = handler;

  @override
  Future<bool> initialize() async {
    if (kIsWeb) return false;
    switch (_platform) {
      case TargetPlatform.iOS:
        await _tts.setSharedInstance(true);
        // Toca mesmo com o aparelho no silencioso e abaixa outros áudios.
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          const [IosTextToSpeechAudioCategoryOptions.duckOthers],
          IosTextToSpeechAudioMode.spokenAudio,
        );
        return true;
      case TargetPlatform.android:
        // Só há nova inicialização após uma falha. O TextToSpeech nativo que
        // falhou (por exemplo, sem motor na abertura do app) não se reconecta
        // sozinho; setEngine cria outro e aguarda a conexão.
        final rebind = _initializedBefore;
        _initializedBefore = true;
        final engines = await _tts.getEngines;
        if (engines is! List || engines.isEmpty) return false;
        if (rebind) {
          final defaultEngine = await _tts.getDefaultEngine;
          await _tts.setEngine(
            engines.contains(defaultEngine)
                ? '$defaultEngine'
                : '${engines.first}',
          );
        }
        return true;
      default:
        return false;
    }
  }

  @override
  Future<bool> setLanguage(String language) async =>
      await _tts.setLanguage(language) == 1;

  @override
  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<bool> speak(String text) async => await _tts.speak(text) == 1;

  @override
  Future<bool> pause() async => await _tts.pause() == 1;

  @override
  Future<void> stop() => _tts.stop();
}

class DeviceSpeechService implements SpeechService {
  DeviceSpeechService({
    TtsEngine? engine,
    this.config = const SpeechConfig(),
    this.timeout = const Duration(seconds: 5),
  }) : _engine = engine ?? FlutterTtsEngine() {
    _engine.setEventHandler(_onEvent);
    // Leitura não continua com o app em segundo plano ou a tela bloqueada.
    _lifecycle = AppLifecycleListener(onHide: () => unawaited(stop()));
  }

  final TtsEngine _engine;
  final SpeechConfig config;

  /// Limite para cada chamada ao motor. No Android, sem motor conectado,
  /// o plugin deixa a chamada pendente indefinidamente.
  final Duration timeout;

  final _status = ValueNotifier(SpeechStatus.idle);
  late final AppLifecycleListener _lifecycle;
  Future<void>? _ready;
  bool _initialized = false;

  /// Cada speak, pause ou stop invalida as operações anteriores ainda em
  /// andamento, para que um texto antigo nunca comece depois do novo.
  int _generation = 0;

  /// Há uma leitura iniciada por este serviço cujos eventos importam.
  bool _active = false;

  /// Ignora a conclusão de um texto anterior que chegue antes do início do
  /// texto atual.
  bool _awaitingStart = false;

  @override
  ValueListenable<SpeechStatus> get status => _status;

  @override
  Future<void> speak(String text) async {
    final generation = ++_generation;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return _interrupt(SpeechStatus.idle);

    await _ensureReady();
    if (generation != _generation) return;
    // Em modo flush o motor já descarta o texto anterior; o stop explícito
    // garante o mesmo nos dois sistemas, mesmo com a leitura pausada.
    _active = false;
    await _stopEngine();
    if (generation != _generation) return;

    _active = true;
    _awaitingStart = true;
    final bool started;
    try {
      started = await _engine.speak(trimmed).timeout(timeout);
    } on TimeoutException catch (error, stackTrace) {
      // O motor deixou de responder; a próxima leitura o inicializa de novo.
      _ready = null;
      _initialized = false;
      _finish(generation);
      throw SpeechEngineUnavailableFailure(error, stackTrace);
    } on Object catch (error) {
      _finish(generation);
      throw SpeechPlaybackFailure(error);
    }
    if (!started) {
      _finish(generation);
      throw const SpeechPlaybackFailure();
    }
    if (generation == _generation) _status.value = SpeechStatus.speaking;
  }

  @override
  Future<void> pause() async {
    final generation = ++_generation;
    // `_active` também cobre um speak cuja chamada ao motor ainda não voltou.
    if (!_active) return;
    final paused = await _call(_engine.pause);
    if (generation != _generation) return;
    if (!paused) return _interrupt(SpeechStatus.idle);
    _active = false;
    _status.value = SpeechStatus.paused;
  }

  @override
  Future<void> stop() {
    ++_generation;
    return _interrupt(SpeechStatus.idle);
  }

  Future<void> dispose() async {
    _lifecycle.dispose();
    await stop();
    _status.dispose();
  }

  Future<void> _ensureReady() async {
    final ready = _ready ??= _initialize();
    try {
      await ready;
    } on Object {
      // Falhas não ficam em cache: o próximo speak tenta novamente.
      if (identical(_ready, ready)) _ready = null;
      rethrow;
    }
  }

  Future<void> _initialize() async {
    try {
      await _configure().timeout(timeout);
      _initialized = true;
    } on SpeechFailure {
      rethrow;
    } on Object catch (error, stackTrace) {
      // Inclui PlatformException, MissingPluginException e TimeoutException.
      throw SpeechEngineUnavailableFailure(error, stackTrace);
    }
  }

  Future<void> _configure() async {
    if (!await _engine.initialize()) {
      throw const SpeechEngineUnavailableFailure();
    }
    if (!await _engine.setLanguage(config.language)) {
      throw SpeechLanguageUnavailableFailure(config.language);
    }
    await _engine.setSpeechRate(config.speechRate);
    await _engine.setPitch(config.pitch);
  }

  Future<void> _interrupt(SpeechStatus next) async {
    _active = false;
    _awaitingStart = false;
    if (_status.value != next) _status.value = next;
    await _stopEngine();
  }

  Future<void> _stopEngine() async {
    // Antes da inicialização não há nada tocando, e o plugin do Android
    // retém as chamadas até o motor responder.
    if (!_initialized) return;
    await _call(() async {
      await _engine.stop();
      return true;
    });
  }

  /// Chamadas que não podem falhar: erros e demora do motor viram `false`.
  Future<bool> _call(Future<bool> Function() action) async {
    try {
      return await action().timeout(timeout);
    } on Object {
      return false;
    }
  }

  void _finish(int generation) {
    if (generation != _generation) return;
    _active = false;
    _awaitingStart = false;
    _status.value = SpeechStatus.idle;
  }

  void _onEvent(TtsEvent event) {
    if (!_active) return;
    switch (event) {
      case TtsEvent.start:
        _awaitingStart = false;
        _status.value = SpeechStatus.speaking;
      case TtsEvent.completion:
        if (_awaitingStart) return;
        _finish(_generation);
      case TtsEvent.error:
        _finish(_generation);
    }
  }
}
