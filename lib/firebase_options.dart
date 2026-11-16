import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class TamleekFirebaseOptions {
  static const _apiKey = String.fromEnvironment('TAMLEEK_FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('TAMLEEK_FIREBASE_APP_ID');
  static const _messagingSenderId = String.fromEnvironment(
    'TAMLEEK_FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _projectId = String.fromEnvironment(
    'TAMLEEK_FIREBASE_PROJECT_ID',
  );
  static const _authDomain = String.fromEnvironment(
    'TAMLEEK_FIREBASE_AUTH_DOMAIN',
  );
  static const _storageBucket = String.fromEnvironment(
    'TAMLEEK_FIREBASE_STORAGE_BUCKET',
  );

  static bool get isConfigured =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _messagingSenderId.isNotEmpty &&
      _projectId.isNotEmpty &&
      _storageBucket.isNotEmpty &&
      (!kIsWeb || _authDomain.isNotEmpty);

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. See the Firebase setup section in README.',
      );
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      authDomain: kIsWeb ? _authDomain : null,
      storageBucket: _storageBucket,
    );
  }
}
