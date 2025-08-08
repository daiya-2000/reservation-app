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

    // Firebase Auth
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');
    when(mockAuth.authStateChanges())
        .thenAnswer((_) => Stream.fromIterable([mockUser]));

    // Firestore - bulletin_posts
    when(mockFirestore.collection('bulletin_posts')).thenReturn(mockCollection);
    when(mockCollection.orderBy('createdAt', descending: true))
        .thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockSnapshot);
    when(mockSnapshot.docs).thenReturn([mockDoc]);
    when(mockDoc.data()).thenReturn({
      'title': 'お知らせ',
      'body': '本文',
      'pdfUrl': null,
      'createdAt': Timestamp.now(),
    });

    // Firestore - notifications (for NotificationTab)
    when(mockFirestore.collection('notifications')).thenReturn(mockCollection);
    when(mockCollection.where('recipients',
        arrayContainsAny: ['test_uid', 'all'])).thenReturn(mockQuery);
    when(mockQuery.orderBy('timestamp', descending: true))
        .thenReturn(mockQuery);
    when(mockQuery.snapshots())
        .thenAnswer((_) => Stream.fromIterable([mockSnapshot]));
    when(mockSnapshot.docs).thenReturn([mockDoc]);

    // Navigator
    when(mockObserver.navigator).thenReturn(null);
  });

  testWidgets('renders correct initial tab and switches on tap',
      (tester) async {
    // モック通知ストリームを作成
    final notificationController =
        StreamController<QuerySnapshot<Map<String, dynamic>>>();
    final mockNotificationSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
    when(mockNotificationSnapshot.docs).thenReturn([mockDoc]);

    // テスト対象ウィジェットをレンダリング
    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(
          auth: mockAuth,
          firestore: mockFirestore,
          functions: mockFunctions,
          notificationStream: notificationController.stream, // ← 注入
        ),
        navigatorObservers: [mockObserver],
      ),
    );

    // 通知ストリームを流す
    notificationController.add(mockNotificationSnapshot);
    await tester.pumpAndSettle();

    // タブがすべて表示されていることを確認
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    expect(find.byIcon(Icons.message), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsOneWidget);

    // 各タブをタップして切り替える
    await tester.tap(find.byIcon(Icons.message));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.calendar_today));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.home));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pump(const Duration(milliseconds: 300));

    await notificationController.close();
  });
}
