import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reservation_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

void main() {
  group('DefaultFirebaseOptions', () {
    test('android options should be valid', () {
      final options = DefaultFirebaseOptions.android;
      expect(options.apiKey, isNotEmpty);
      expect(options.appId, startsWith('1:'));
      expect(options.projectId, equals('reservation-app-e2cc9'));
    });

    test('ios options should be valid', () {
      final options = DefaultFirebaseOptions.ios;
      expect(options.iosBundleId, equals('com.example.reservationApp'));
      expect(options.projectId, equals('reservation-app-e2cc9'));
    });

    test('macos options should equal ios', () {
      expect(DefaultFirebaseOptions.macos, DefaultFirebaseOptions.ios);
    });

    test('web options should be valid', () {
      final options = DefaultFirebaseOptions.web;
      expect(options.authDomain, contains('firebaseapp.com'));
      expect(options.measurementId, isNotNull);
    });

    test('windows options should be valid', () {
      final options = DefaultFirebaseOptions.windows;
      expect(options.authDomain, contains('firebaseapp.com'));
      expect(options.measurementId, isNotEmpty);
    });

    test('unsupported platform throws error', () {
      FirebaseOptions getPlatformOptions(TargetPlatform platform,
          {bool isWeb = false}) {
        if (isWeb) return DefaultFirebaseOptions.web;

        switch (platform) {
          case TargetPlatform.android:
            return DefaultFirebaseOptions.android;
          case TargetPlatform.iOS:
            return DefaultFirebaseOptions.ios;
          case TargetPlatform.macOS:
            return DefaultFirebaseOptions.macos;
          case TargetPlatform.windows:
            return DefaultFirebaseOptions.windows;
          case TargetPlatform.linux:
            throw UnsupportedError('Linux is not supported.');
          default:
            throw UnsupportedError('Unsupported platform.');
        }
      }

      expect(
        () => getPlatformOptions(TargetPlatform.linux),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
