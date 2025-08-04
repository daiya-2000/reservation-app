import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:reservation_app/admin_screen.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockFirebaseFunctions extends Mock implements FirebaseFunctions {}

void main() {
  group('AdminScreen UI test', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseFunctions mockFunctions;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockFunctions = MockFirebaseFunctions();
    });

    testWidgets('AdminScreen renders and shows correct navigation labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdminScreen(
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
        ),
      );

      // 初期描画を反映
      await tester.pumpAndSettle();

      expect(find.text('管理マンション一覧'), findsWidgets); // ← 修正点
      expect(find.text('管理人アカウント一覧'), findsWidgets); // ← 修正点
      expect(find.text('プロフィール'), findsWidgets); // ← 修正点
      expect(find.text('ログアウト'), findsWidgets); // ← 修正点
    });
  });
}
