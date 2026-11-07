import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opções do Firebase fornecidas pelo ambiente de compilação.
/// Use --dart-define-from-file=config/firebase.local.json ao executar/buildar.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Firebase não configurado para web.');
    }
    return forPlatform(defaultTargetPlatform);
  }

  /// Valida os campos antes de chamar Firebase.initializeApp no Dart.
  /// [options] permite fornecer outra configuração ou uma fixture de teste.
  static FirebaseOptions forPlatform(
    TargetPlatform platform, {
    FirebaseOptions? options,
  }) {
    final selected = switch (platform) {
      TargetPlatform.android => options ?? android,
      TargetPlatform.iOS => options ?? ios,
      _ => throw UnsupportedError(
        'Firebase não configurado para ${platform.name}.',
      ),
    };
    final prefix = platform == TargetPlatform.android ? 'ANDROID' : 'IOS';
    final requiredValues = {
      'FIREBASE_${prefix}_API_KEY': selected.apiKey,
      'FIREBASE_${prefix}_APP_ID': selected.appId,
      'FIREBASE_MESSAGING_SENDER_ID': selected.messagingSenderId,
      'FIREBASE_PROJECT_ID': selected.projectId,
      if (platform == TargetPlatform.iOS)
        'FIREBASE_IOS_BUNDLE_ID': selected.iosBundleId ?? '',
    };
    final missing = requiredValues.entries
        .where((entry) => entry.value.trim().isEmpty)
        .map((entry) => entry.key)
        .toList();
    if (missing.isNotEmpty) {
      throw StateError(
        'Configuração Firebase incompleta: ${missing.join(', ')}. '
        'Preencha config/firebase.local.json a partir do exemplo e use '
        '--dart-define-from-file=config/firebase.local.json.',
      );
    }
    return selected;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_ANDROID_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment('FIREBASE_IOS_API_KEY'),
    appId: String.fromEnvironment('FIREBASE_IOS_APP_ID'),
    messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
  );
}
