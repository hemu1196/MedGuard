// File generated for MedGuard-AI (medguard-ai-8e484).
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Project Name: MedGuard-AI
/// Project ID: medguard-ai-8e484
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmshcWLmsbvo2BYCFAq-MA2YNAY5R97V8',
    appId: '1:544924235532:web:14a79ddfa661959d873b29',
    messagingSenderId: '544924235532',
    projectId: 'medguard-ai-8e484',
    authDomain: 'medguard-ai-8e484.firebaseapp.com',
    storageBucket: 'medguard-ai-8e484.firebasestorage.app',
    measurementId: 'G-2F5K7F7TGC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDLqTOncGNIfQKOX7uhcH3RUseGliaQhQ',
    appId: '1:544924235532:android:1a11d9cdfbda8b8e873b29',
    messagingSenderId: '544924235532',
    projectId: 'medguard-ai-8e484',
    storageBucket: 'medguard-ai-8e484.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAPgEdv2miUZ3FIinNGhzb68lOkGFe9vaI',
    appId: '1:544924235532:ios:d8565815b6ee6cbc873b29',
    messagingSenderId: '544924235532',
    projectId: 'medguard-ai-8e484',
    storageBucket: 'medguard-ai-8e484.firebasestorage.app',
    iosBundleId: 'com.example.medAi',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAPgEdv2miUZ3FIinNGhzb68lOkGFe9vaI',
    appId: '1:544924235532:ios:d8565815b6ee6cbc873b29',
    messagingSenderId: '544924235532',
    projectId: 'medguard-ai-8e484',
    storageBucket: 'medguard-ai-8e484.firebasestorage.app',
    iosBundleId: 'com.example.medAi',
  );
}
