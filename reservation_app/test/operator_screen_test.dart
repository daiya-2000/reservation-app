import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:reservation_app/operator_screen.dart';

import 'operator_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseFunctions,
  User,
  DocumentSnapshot,
  DocumentReference,
  CollectionReference,
  Query,
  QuerySnapshot,
])
void main() {
  group('OperatorScreen tests', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseFunctions mockFunctions;
    late MockUser mockUser;
    late MockDocumentSnapshot<Map<String, dynamic>> mockUserDoc;
    late MockDocumentReference<Map<String, dynamic>> mockUserRef;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockCollectionReference<Map<String, dynamic>>
        mockBulletinPostsCollection;
    late MockQuerySnapshot<Map<String, dynamic>> mockBulletinQuerySnapshot;

    setUp(() {
      mockBulletinPostsCollection =
          MockCollectionReference<Map<String, dynamic>>();
      mockBulletinQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockFunctions = MockFirebaseFunctions();
      mockUser = MockUser();
      mockUserDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      mockUserRef = MockDocumentReference<Map<String, dynamic>>();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();

      // Firebase Auth 設定
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_uid');

      // Firestore 設定
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.doc('test_uid')).thenReturn(mockUserRef);
      when(mockUserRef.get()).thenAnswer((_) async => mockUserDoc);
      when(mockUserDoc.exists).thenReturn(true);
      when(mockUserDoc.data()).thenReturn({'apartment': 'test_apartment_id'});
      when(mockFirestore.collection('bulletin_posts'))
          .thenReturn(mockBulletinPostsCollection);
      final mockQuery = MockQuery<Map<String, dynamic>>();
      when(mockBulletinPostsCollection.orderBy('createdAt', descending: true))
          .thenReturn(mockQuery);
      when(mockQuery.get()).thenAnswer((_) async => mockBulletinQuerySnapshot);
      when(mockBulletinQuerySnapshot.docs).thenReturn([]);
      final mockWhereQuery = MockQuery<Map<String, dynamic>>();
      when(mockFirestore.collection('bulletin_posts'))
          .thenReturn(mockBulletinPostsCollection);

      // 'where' に対するスタブ追加
      when(mockBulletinPostsCollection.where('apartmentId',
              isEqualTo: 'test_apartment_id'))
          .thenReturn(mockWhereQuery);

      // 'orderBy' に対するスタブも chained で必要
      when(mockWhereQuery.orderBy('createdAt', descending: true))
          .thenReturn(mockWhereQuery);

      when(mockWhereQuery.get())
          .thenAnswer((_) async => mockBulletinQuerySnapshot);

      when(mockBulletinQuerySnapshot.docs).thenReturn([]);
    });

    testWidgets('OperatorScreen shows loading and then dashboard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OperatorScreen(
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
        ),
      );

      // 初期状態はローディング
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Firestore 読み込み後
      await tester.pumpAndSettle();
      expect(find.text('マンション管理者ダッシュボード'), findsOneWidget);
      expect(find.byType(NavigationRail), findsOneWidget);
    });

    testWidgets('OperatorScreen navigation changes content',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OperatorScreen(
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 「掲示板」をタップ
      await tester.tap(find.text('掲示板'));
      await tester.pumpAndSettle();

      expect(find.text('掲示板'), findsWidgets); // 複数箇所で使われている
    });

    testWidgets('Logout shows dialog and logs out',
        (WidgetTester tester) async {
      bool signOutCalled = false;
      when(mockAuth.signOut()).thenAnswer((_) async {
        signOutCalled = true;
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OperatorScreen(
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
          routes: {
            '/login': (context) => const Scaffold(body: Text('ログイン画面')),
          },
        ),
      );

      await tester.pumpAndSettle();

      // ログアウトボタンタップ
      await tester.tap(find.text('ログアウト'));
      await tester.pumpAndSettle();

      // ダイアログ表示
      expect(find.text('ログアウトしますか？'), findsOneWidget);

      // 「ログアウト」ボタン押下
      await tester.tap(find.widgetWithText(ElevatedButton, 'ログアウト'));
      await tester.pumpAndSettle();

      // サインアウトが呼ばれ、ログイン画面に遷移
      expect(signOutCalled, isTrue);
      expect(find.text('ログイン画面'), findsOneWidget);
    });
  });
}
