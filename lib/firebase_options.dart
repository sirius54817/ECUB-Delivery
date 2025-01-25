import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI again.',
      );
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

  static const FirebaseOptions android = FirebaseOptions(
 apiKey: 'AIzaSyD0wKXUZHUBAtRyna9jcKX2eCdANf_DERY',
 appId: '1:732286850360:android:09daca422e3e20b4709dcd',
 messagingSenderId: '732286850360', 
 projectId: 'carpool-6e70b',
 storageBucket: 'carpool-6e70b.firebasestorage.app',
);
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD0wKXUZHUBAtRyna9jcKX2eCdANf_DERY',
    appId: '1:732286850360:ios:09daca422e3e20b4709dcd',
    messagingSenderId: '732286850360',
    projectId: 'carpool-6e70b',
    storageBucket: 'carpool-6e70b.firebasestorage.app',
  );
}