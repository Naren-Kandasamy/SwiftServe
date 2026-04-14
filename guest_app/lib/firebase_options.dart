// firebase_options.dart — generated for Mobile platform
// TODO: Replace placeholder values with real values from your Firebase Console.
// Go to: Firebase Console → Project Settings → Your apps → iOS/Android → SDK setup and config.
// Alternatively run: `dart pub global activate flutterfire_cli && flutterfire configure`

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ─── Web ───────────────────────────────────────────────────────────────────
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdfN24mSTHuxE2UV8oghB0fQwdRnTsfu8',
    appId: '1:501246692657:web:c6d919305888bddce43410',
    messagingSenderId: '501246692657',
    projectId: 'swiftserve-18547',
    authDomain: 'swiftserve-18547.firebaseapp.com',
    databaseURL: 'https://swiftserve-18547-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'swiftserve-18547.firebasestorage.app',
  );

  // ─── Android ────────────────────────────────────────────────────────────────
  // Replace every value here with what you see in Firebase Console → Android App Config
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://swiftserve-18547-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );

  // ─── iOS ────────────────────────────────────────────────────────────────────
  // Replace every value here with what you see in Firebase Console → iOS App Config
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    databaseURL: 'https://swiftserve-18547-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
    iosBundleId: 'com.example.guestApp',
  );
}
