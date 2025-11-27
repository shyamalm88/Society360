// File generated manually from Firebase configuration files
// This file contains the Firebase configuration for the app

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAvuLAzp-rYqxaPAKVxGPcz9970Tn7fbTI',
    appId: '1:161086137868:web:YOUR_WEB_APP_ID',
    messagingSenderId: '161086137868',
    projectId: 'society360-b8abe',
    authDomain: 'society360-b8abe.firebaseapp.com',
    storageBucket: 'society360-b8abe.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAvuLAzp-rYqxaPAKVxGPcz9970Tn7fbTI',
    appId: '1:161086137868:android:46ea87201adb018b88f029',
    messagingSenderId: '161086137868',
    projectId: 'society360-b8abe',
    storageBucket: 'society360-b8abe.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAKkgC2w93MI-GoMQFrWNWqZ18Ue-38Nq4',
    appId: '1:161086137868:ios:4a2b6c86ea3345bb88f029',
    messagingSenderId: '161086137868',
    projectId: 'society360-b8abe',
    storageBucket: 'society360-b8abe.firebasestorage.app',
    iosBundleId: 'com.society360.society360Resident',
  );
}
