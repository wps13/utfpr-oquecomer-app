import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/widgets/hands_free_voice_status.dart';

void main() {
  Future<void> pump(WidgetTester tester, HandsFreeVoiceStatus status) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Center(child: SizedBox(width: 380, child: status)),
          ),
        ),
      );

  testWidgets('distinguishes listening from playback', (tester) async {
    await pump(
      tester,
      HandsFreeVoiceStatus(
        state: VoiceCaptureState.listening,
        enabled: true,
        isReading: false,
        onActivate: () {},
        onOpenSettings: () {},
      ),
    );
    expect(find.text('Ouvindo'), findsOneWidget);
    expect(find.byIcon(Icons.mic), findsOneWidget);
    expect(find.text('Ativar comandos de voz'), findsNothing);

    await pump(
      tester,
      HandsFreeVoiceStatus(
        state: VoiceCaptureState.suspended,
        enabled: true,
        isReading: true,
        onActivate: () {},
        onOpenSettings: () {},
      ),
    );
    expect(find.text('Ouvindo'), findsNothing);
    expect(find.text('Lendo o passo'), findsOneWidget);
    expect(
      find.text('A escuta volta automaticamente ao terminar a leitura.'),
      findsOneWidget,
    );
  });

  testWidgets('disabled mode offers activation even with stale capture state', (
    tester,
  ) async {
    var activations = 0;
    await pump(
      tester,
      HandsFreeVoiceStatus(
        state: VoiceCaptureState.listening,
        enabled: false,
        isReading: false,
        onActivate: () => activations++,
        onOpenSettings: () {},
      ),
    );
    expect(find.text('Comandos de voz desativados'), findsOneWidget);
    expect(find.text('Ouvindo'), findsNothing);
    await tester.tap(find.text('Ativar comandos de voz'));
    expect(activations, 1);
  });

  testWidgets('offers settings only for permanent denial and keeps retry', (
    tester,
  ) async {
    var activations = 0;
    var settings = 0;
    for (final access in [
      PermissionAccess.denied,
      PermissionAccess.permanentlyDenied,
    ]) {
      await pump(
        tester,
        HandsFreeVoiceStatus(
          state: VoiceCaptureState.failed,
          enabled: true,
          isReading: false,
          failure: VoiceFailure(
            VoiceFailureKind.microphoneDenied,
            permissionAccess: access,
          ),
          onActivate: () => activations++,
          onOpenSettings: () => settings++,
        ),
      );
      expect(find.text('Modo por voz indisponível'), findsOneWidget);
      expect(
        find.textContaining('Permita o acesso ao microfone'),
        findsOneWidget,
      );
      await tester.tap(find.text('Ativar comandos de voz'));
      if (access == PermissionAccess.permanentlyDenied) {
        await tester.tap(find.text('Abrir configurações'));
      } else {
        expect(find.text('Abrir configurações'), findsNothing);
      }
    }
    expect(activations, 2);
    expect(settings, 1);
  });
}
