import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/services/speech/speech_service.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/speech_status.dart';

/// Leitura em voz alta do passo atual no modo mãos livres. A leitura é
/// interrompida quando a tela sai da árvore e a ViewModel é descartada.
class HandsFreeViewModel extends ChangeNotifier {
  HandsFreeViewModel({required SpeechService speechService})
    : _speech = speechService {
    _speech.status.addListener(_onStatusChanged);
  }

  final SpeechService _speech;

  String? _errorMessage;
  bool _disposed = false;

  SpeechStatus get speechStatus => _speech.status.value;
  String? get errorMessage => _errorMessage;

  /// Lê [text], substituindo a leitura em andamento.
  Future<void> readStep(String text) async {
    _setError(null);
    try {
      await _speech.speak(text);
    } on SpeechFailure catch (failure) {
      _setError(failure.message);
    }
  }

  Future<void> pause() => _speech.pause();

  Future<void> stop() => _speech.stop();

  void _onStatusChanged() {
    if (!_disposed) notifyListeners();
  }

  void _setError(String? message) {
    if (_disposed || _errorMessage == message) return;
    _errorMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _speech.status.removeListener(_onStatusChanged);
    unawaited(_speech.stop());
    super.dispose();
  }
}
