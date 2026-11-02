import 'package:flutter/foundation.dart';
import 'package:o_que_comer_app/data/services/speech/speech_service.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/speech_status.dart';

/// Serviço de leitura falso para testes de ViewModel e de navegação.
class FakeSpeechService implements SpeechService {
  final _status = ValueNotifier(SpeechStatus.idle);
  final spoken = <String>[];
  int pauseCalls = 0;
  int stopCalls = 0;
  SpeechFailure? failure;

  @override
  ValueListenable<SpeechStatus> get status => _status;

  @override
  Future<void> speak(String text) async {
    final error = failure;
    if (error != null) throw error;
    spoken.add(text);
    _status.value = SpeechStatus.speaking;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    if (_status.value == SpeechStatus.speaking) {
      _status.value = SpeechStatus.paused;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _status.value = SpeechStatus.idle;
  }
}
