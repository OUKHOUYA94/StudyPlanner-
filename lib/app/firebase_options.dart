import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Firebase configuration for each platform.
/// Replace placeholder values with your actual Firebase project config
/// from google-services.json.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA83l1VpT20djZFvpK9-XCOSztZ6HNRZOc',
    appId: '1:58176211308:android:d9d337b290196ba10d4b49',
    messagingSenderId: '58176211308',
    projectId: 'studyplanner-dev-emg',
    storageBucket: 'studyplanner-dev-emg.firebasestorage.app',
  );
}
