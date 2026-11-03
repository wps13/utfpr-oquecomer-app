import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';

void main() {
  test(
    'cada falha tem mensagem em português e identificação sem transcrição',
    () {
      for (final kind in VoiceFailureKind.values) {
        final failure = VoiceFailure(kind);
        expect(failure.message, isNotEmpty);
        expect(failure.toString(), 'VoiceFailure(${kind.name})');
        expect(failure.canOpenSettings, isFalse);
      }
      expect(
        const VoiceFailure(VoiceFailureKind.microphoneDenied).message,
        isNot(
          const VoiceFailure(VoiceFailureKind.recognitionUnavailable).message,
        ),
      );
    },
  );

  test('recusa permanente e restrição podem ser recuperadas nos ajustes', () {
    for (final access in PermissionAccess.values) {
      final failure = VoiceFailure(
        VoiceFailureKind.microphoneDenied,
        permissionAccess: access,
      );
      expect(
        failure.canOpenSettings,
        access == PermissionAccess.permanentlyDenied ||
            access == PermissionAccess.restricted,
      );
    }
  });
}
