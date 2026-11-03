import 'dart:async';

import 'package:o_que_comer_app/data/services/voice/voice_recognition_engine.dart';

class FakeVoiceRecognitionEngine implements VoiceRecognitionEngine {
  bool available = true;
  List<String> supportedLocales = ['en-US', 'pt_BR'];
  int initializeCalls = 0;
  int cancelCalls = 0;
  int listenCalls = 0;
  String? lastLocale;
  bool emitListening = true;
  Object? initializeError;
  Object? listenError;
  Object? cancelError;
  Completer<bool>? pendingInitialization;
  void Function(VoiceEngineStatus)? statusListener;
  void Function(String)? errorListener;
  final results = <VoiceResultListener>[];

  @override
  Future<bool> initialize({
    required void Function(VoiceEngineStatus status) onStatus,
    required void Function(String code) onError,
  }) async {
    initializeCalls++;
    statusListener = onStatus;
    errorListener = onError;
    if (initializeError != null) {
      Error.throwWithStackTrace(initializeError!, StackTrace.current);
    }
    return pendingInitialization?.future ?? available;
  }

  @override
  Future<List<String>> locales() async => supportedLocales;

  @override
  Future<void> listen({
    required String localeId,
    required VoiceResultListener onResult,
  }) async {
    listenCalls++;
    lastLocale = localeId;
    if (listenError != null) {
      Error.throwWithStackTrace(listenError!, StackTrace.current);
    }
    results.add(onResult);
    if (emitListening) statusListener!(VoiceEngineStatus.listening);
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    if (cancelError != null) {
      Error.throwWithStackTrace(cancelError!, StackTrace.current);
    }
    statusListener?.call(VoiceEngineStatus.done);
  }

  void result(String text, {bool isFinal = true, int? session}) =>
      results[session ?? results.length - 1](text, isFinal: isFinal);

  void status(VoiceEngineStatus status) => statusListener!(status);
  void error(String code) => errorListener!(code);
}
