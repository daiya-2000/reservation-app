import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:reservation_app/operator_screen.dart';

import 'operator_account_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  FirebaseAuth,
  FirebaseFunctions,
])
void main() {
  group('AccountScreen Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockQuery<Map<String, dynamic>> mockQuery1;
    late MockQuery<Map<String, dynamic>> mockQuery2;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDoc;

    late MockFirebaseAuth mockAuth;
    late MockFirebaseFunctions mockFunctions;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockQuery1 = MockQuery<Map<String, dynamic>>();
      mockQuery2 = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      mockAuth = MockFirebaseAuth();
      mockFunctions = MockFirebaseFunctions();

      // クエリチェーン
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.where('apartment', isEqualTo: 'apt1'))
          .thenReturn(mockQuery1);
      when(mockQuery1.where('role', isEqualTo: 'Resident'))
          .thenReturn(mockQuery2);
      when(mockQuery2.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockDoc]);
      when(mockDoc.id).thenReturn('user1');
      when(mockDoc.data()).thenReturn({
        'name': '佐藤',
        'roomNumber': '101',
        'role': 'Resident',
        'apartment': 'apt1',
      });
    });

    testWidgets('renders residents correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AccountScreen(
            apartmentId: 'apt1',
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
        ),
      );

      // 非同期完了まで待つ
      await tester.pumpAndSettle();

      // タイトル確認
      expect(find.text('住人アカウント一覧'), findsOneWidget);

      // ボタン確認
      expect(find.text('新規住人アカウント作成'), findsOneWidget);

      // リスト表示確認
      expect(find.text('佐藤'), findsOneWidget);
      expect(find.text('部屋番号: 101'), findsOneWidget);
    });
  });
}
