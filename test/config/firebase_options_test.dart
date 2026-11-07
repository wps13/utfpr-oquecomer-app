import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/firebase_options.dart';

const androidFixture = FirebaseOptions(
  apiKey: 'android-fixture-key',
  appId: '1:123:android:fixture',
  messagingSenderId: '123',
  projectId: 'fixture-project',
);

const iosFixture = FirebaseOptions(
  apiKey: 'ios-fixture-key',
  appId: '1:123:ios:fixture',
  messagingSenderId: '123',
  projectId: 'fixture-project',
  iosBundleId: 'org.example.fixture',
);

void main() {
  test('configuração Android válida pode omitir o bucket não utilizado', () {
    expect(
      DefaultFirebaseOptions.forPlatform(
        TargetPlatform.android,
        options: androidFixture,
      ),
      same(androidFixture),
    );
  });

  test('configuração iOS válida preserva o registro e bundle ID', () {
    expect(
      DefaultFirebaseOptions.forPlatform(
        TargetPlatform.iOS,
        options: iosFixture,
      ),
      same(iosFixture),
    );
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('chave ausente em ${platform.name} informa o nome da variável', () {
      const fixture = FirebaseOptions(
        apiKey: ' ',
        appId: 'fixture-app-id',
        messagingSenderId: '123',
        projectId: 'fixture-project',
        iosBundleId: 'org.example.fixture',
      );
      final prefix = platform == TargetPlatform.android ? 'ANDROID' : 'IOS';
      expect(
        () => DefaultFirebaseOptions.forPlatform(platform, options: fixture),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('FIREBASE_${prefix}_API_KEY'),
          ),
        ),
      );
    });
  }

  test('configuração incompleta lista os campos sem expor valores', () {
    const fixture = FirebaseOptions(
      apiKey: 'fixture-value-that-must-not-appear-in-errors',
      appId: '',
      messagingSenderId: '',
      projectId: '',
    );
    expect(
      () => DefaultFirebaseOptions.forPlatform(
        TargetPlatform.android,
        options: fixture,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          allOf(
            contains('FIREBASE_ANDROID_APP_ID'),
            contains('FIREBASE_MESSAGING_SENDER_ID'),
            contains('FIREBASE_PROJECT_ID'),
            contains('--dart-define-from-file=config/firebase.local.json'),
            isNot(contains(fixture.apiKey)),
          ),
        ),
      ),
    );
  });

  test('bundle ID ausente impede inicialização iOS', () {
    expect(
      () => DefaultFirebaseOptions.forPlatform(
        TargetPlatform.iOS,
        options: androidFixture,
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('FIREBASE_IOS_BUNDLE_ID'),
        ),
      ),
    );
  });

  test('plataformas não configuradas têm erro explícito', () {
    expect(
      () => DefaultFirebaseOptions.forPlatform(TargetPlatform.linux),
      throwsUnsupportedError,
    );
  });
}
