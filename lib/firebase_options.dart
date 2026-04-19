// GENERATED FILE — PLACEHOLDER.
// Replace by running: flutterfire configure --project=<your-project-id>
// The command will overwrite this file with real API keys/options for
// each platform (iOS, Android, macOS, web). Do not commit real values.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return _placeholder('web');
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _placeholder('android');
      case TargetPlatform.iOS:
        return _placeholder('ios');
      case TargetPlatform.macOS:
        return _placeholder('macos');
      default:
        throw UnsupportedError(
          'Unsupported platform. Run `flutterfire configure` to regenerate.',
        );
    }
  }

  static FirebaseOptions _placeholder(String platform) => FirebaseOptions(
        apiKey: 'REPLACE_ME_$platform',
        appId: 'REPLACE_ME_$platform',
        messagingSenderId: 'REPLACE_ME',
        projectId: 'REPLACE_ME',
        storageBucket: 'REPLACE_ME.appspot.com',
      );
}
