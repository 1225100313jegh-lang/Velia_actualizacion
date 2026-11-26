import 'package:firebase_core/firebase_core.dart';

/// Opciones de Firebase tomadas de android/app/google-services.json.
class FirebaseOptionsVelia {
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY',
      defaultValue: 'AIzaSyCsUY7kWCBBThFa0QrOtrrXUajwpIWqsEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID',
      defaultValue: '1:49145979058:android:540d296977a1b36fcee9ab');
  static const messagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '49145979058');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID',
      defaultValue: 'velia-1a9ea');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');

  static bool get configured =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static FirebaseOptions get currentPlatform => FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain.isEmpty ? null : authDomain,
      );
}
