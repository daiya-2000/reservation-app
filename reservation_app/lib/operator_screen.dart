import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:reservation_app/main_screen.dart';
import 'main_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseFunctions,
  User,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  NavigatorObserver,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockSnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDoc;
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockUser = MockUser();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockDoc = MockQueryDocumentSnapshot();
    mockObserver = MockNavigatorObserver();

    // Auth
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.fromIterable([mockUser]));
    when(mockUser.uid).thenReturn('test_uid');

    // Firestore - notifications
    when(mockFirestore.collection('notifications')).thenReturn(mockCollection);
    when(mockCollection.where('recipients',
        arrayContainsAny: ['test_uid', 'all'])).thenReturn(mockQuery);
    when(mockQuery.orderBy('timestamp', descending: true))
        .thenReturn(mockQuery);
    when(mockQuery.snapshots())
        .thenAnswer((_) => Stream.fromIterable([mockSnapshot]));
    when(mockSnapshot.docs).thenReturn([mockDoc]);
    when(mockDoc.data()).thenReturn({
      'title': '通知タイトル',
      'body': '通知内容',
      'timestamp': Timestamp.now(),
    });

    // Firestore - bulletin_posts
    when(mockFirestore.collection('bulletin_posts')).thenReturn(mockCollection);
    when(mockCollection.orderBy('createdAt', descending: true))
        .thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(mockSnapshot.docs).thenReturn([mockDoc]);
    when(mockDoc.data()).thenReturn({
      'title': '掲示板タイトル',
      'body': '掲示板本文',
      'pdfUrl': null,
      'createdAt': Timestamp.now(),
    });

    // NavigatorObserver
    when(mockObserver.navigator).thenReturn(null);
  });

  testWidgets('renders correct initial tab and switches on tap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          auth: mockAuth,
          firestore: mockFirestore,
          functions: mockFunctions,
        ),
        navigatorObservers: [mockObserver],
      ),
    );

    // 通常の非同期完了を明示的に待つ（無限待機を避ける）
    await tester.pump(const Duration(seconds: 1));

    // タブがすべて表示されていることを確認
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.message), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);

    // 各タブをタップして切り替える
    await tester.tap(find.byIcon(Icons.message));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.home));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
