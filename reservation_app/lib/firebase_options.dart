import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

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
          'DefaultFirebaseOptions have not been configured for Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const _projectId = 'reservation-app-e2cc9';
  static const _storageBucket = 'reservation-app-e2cc9.firebasestorage.app';
  static const _messagingSenderId = '395060331810';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDzZtmkC1xisv2sJhQ8GoiG_qtsBON9LLw',
    appId: '1:395060331810:web:494bdbc3fc70cb8495d17b',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: 'reservation-app-e2cc9.firebaseapp.com',
    storageBucket: _storageBucket,
    measurementId: 'G-ND86MC1F81',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBI75bBRwxUg-ANw98FFwxj2uNprwQUWG0',
    appId: '1:395060331810:android:872f2077f456e37695d17b',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDnaFTCC_TcpknmtfHS6Whtz9tH_1FHUnw',
    appId: '1:395060331810:ios:33f2b7a01b1a33cc95d17b',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: 'com.example.reservationApp',
  );

  static const FirebaseOptions macos = ios; // 同一設定

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDzZtmkC1xisv2sJhQ8GoiG_qtsBON9LLw',
    appId: '1:395060331810:web:c20cdc5db9888be595d17b',
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: 'reservation-app-e2cc9.firebaseapp.com',
    storageBucket: _storageBucket,
    measurementId: 'G-789GVZYBZG',
  );
}
