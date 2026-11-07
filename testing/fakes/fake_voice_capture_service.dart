import 'dart:async';

import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';

/// Sem microfone nem timers; mantém o contrato de suspensão durante o áudio.
class FakeVoiceCaptureService implements VoiceCaptureService {
  final _transcripts = StreamController<String>.broadcast(sync: true);
  final _failures = StreamController<VoiceFailure>.broadcast(sync: true);
  final _states = StreamController<VoiceCaptureState>.broadcast(sync: true);
  VoiceCaptureState _state = VoiceCaptureState.stopped;
  bool _wanted = false;
  int _holds = 0;
  int startCalls = 0;
  int stopCalls = 0;
  VoiceFailure? startFailure;

  @override
  Stream<String> get transcripts => _transcripts.stream;
  @override
  Stream<VoiceFailure> get failures => _failures.stream;
  @override
  Stream<VoiceCaptureState> get states => _states.stream;
  @override
  VoiceCaptureState get state => _state;

  void _setState(VoiceCaptureState state) {
    _state = state;
    _states.add(state);
  }

  void emit(String text) {
    if (_state == VoiceCaptureState.listening) _transcripts.add(text);
  }

  @override
  Future<void> start() async {
    startCalls++;
    _wanted = true;
    final failure = startFailure;
    if (failure != null) {
      _wanted = false;
      _setState(VoiceCaptureState.failed);
      _failures.add(failure);
      return;
    }
    _setState(
      _holds > 0 ? VoiceCaptureState.suspended : VoiceCaptureState.listening,
    );
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _wanted = false;
    _setState(VoiceCaptureState.stopped);
  }

  @override
  Future<T> duringPlayback<T>(Future<T> Function() playback) async {
    _holds++;
    if (_wanted) _setState(VoiceCaptureState.suspended);
    try {
      return await playback();
    } finally {
      _holds--;
      if (_wanted && _holds == 0) _setState(VoiceCaptureState.listening);
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    unawaited(_transcripts.close());
    unawaited(_failures.close());
    unawaited(_states.close());
  }
}
