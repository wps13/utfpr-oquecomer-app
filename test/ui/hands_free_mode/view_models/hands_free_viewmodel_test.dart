import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/speech_status.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/hands_free_viewmodel.dart';

import '../../../../testing/fakes/fake_speech_service.dart';

void main() {
  late FakeSpeechService speech;
  late HandsFreeViewModel viewModel;
  late int notifications;

  setUp(() {
    speech = FakeSpeechService();
    viewModel = HandsFreeViewModel(speechService: speech);
    notifications = 0;
    viewModel.addListener(() => notifications++);
  });

  test('reads the step and mirrors the speech status', () async {
    await viewModel.readStep('Pique a cebola.');

    expect(speech.spoken, ['Pique a cebola.']);
    expect(viewModel.speechStatus, SpeechStatus.speaking);
    expect(notifications, 1);

    await viewModel.pause();
    expect(viewModel.speechStatus, SpeechStatus.paused);

    await viewModel.stop();
    expect(viewModel.speechStatus, SpeechStatus.idle);
    expect(notifications, 3);

    viewModel.dispose();
  });

  test('exposes the failure message and clears it on success', () async {
    speech.failure = const SpeechEngineUnavailableFailure();

    await viewModel.readStep('Passo 1');

    expect(
      viewModel.errorMessage,
      const SpeechEngineUnavailableFailure().message,
    );

    speech.failure = null;
    await viewModel.readStep('Passo 1');

    expect(viewModel.errorMessage, isNull);
    viewModel.dispose();
  });

  test('dispose stops the reading and stops listening', () async {
    await viewModel.readStep('Passo 1');

    viewModel.dispose();

    expect(speech.stopCalls, 1);
    expect(speech.status.value, SpeechStatus.idle);
  });
}
