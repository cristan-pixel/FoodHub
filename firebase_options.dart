// lib/firebase_options.dart
//
// This file tells the app WHICH Firebase project to connect to. It is
// normally generated for you by the FlutterFire CLI:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure
//
// That command asks you to pick your Firebase project and writes your
// real project IDs/keys here (plus the android/google-services.json for
// Android). Until you run it, the app happily stays in "offline demo
// mode" — every screen still works with the local demo data and never
// crashes.
//
// You can also fill the values in by hand from your Firebase console:
//   Project settings ▸ General ▸ Your apps ▸ (the app for this platform)
//
// Don't commit real keys to a public repo.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running `flutterfire configure`.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not configured for this platform.',
        );
    }
  }

  // ── PLACEHOLDERS — replace with your real values (or run

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCxEp8jyyr8F6YnqQ8ZMkYHUZHgdPgWtc0',
    appId: '1:1049205401174:android:14ac57cce574c7db36bdf7',
    messagingSenderId: '1049205401174',
    projectId: 'foodhub-2ef45',
    storageBucket: 'foodhub-2ef45.firebasestorage.app',
  );

  //    `flutterfire configure` which overwrites this file for you). ──

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD6fCAsGs51B8WLKo6YA-lNYyrwTmWa4Pg',
    appId: '1:1049205401174:ios:1325abc465b103db36bdf7',
    messagingSenderId: '1049205401174',
    projectId: 'foodhub-2ef45',
    storageBucket: 'foodhub-2ef45.firebasestorage.app',
    iosBundleId: 'com.example.finalfoodhub',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD6fCAsGs51B8WLKo6YA-lNYyrwTmWa4Pg',
    appId: '1:1049205401174:ios:1325abc465b103db36bdf7',
    messagingSenderId: '1049205401174',
    projectId: 'foodhub-2ef45',
    storageBucket: 'foodhub-2ef45.firebasestorage.app',
    iosBundleId: 'com.example.finalfoodhub',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAfhB-LHEN7rhkFxTMX8_4M0bcDNE68TS0',
    appId: '1:1049205401174:web:d837b6ad5f67079b36bdf7',
    messagingSenderId: '1049205401174',
    projectId: 'foodhub-2ef45',
    authDomain: 'foodhub-2ef45.firebaseapp.com',
    storageBucket: 'foodhub-2ef45.firebasestorage.app',
    measurementId: 'G-0SSSZ54E7H',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAfhB-LHEN7rhkFxTMX8_4M0bcDNE68TS0',
    appId: '1:1049205401174:web:98554de78314684436bdf7',
    messagingSenderId: '1049205401174',
    projectId: 'foodhub-2ef45',
    authDomain: 'foodhub-2ef45.firebaseapp.com',
    storageBucket: 'foodhub-2ef45.firebasestorage.app',
    measurementId: 'G-EWCDYXBE7K',
  );

}