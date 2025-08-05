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
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockSnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDoc;
  late MockFirebaseFunctions mockFunctions;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockDoc = MockQueryDocumentSnapshot();
    mockFunctions = MockFirebaseFunctions();
  });

  testWidgets('renders correct initial tab and switches on tap',
      (tester) async {
    // Firebase Auth モック
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    // Firestore 通知ストリームのモック
    when(mockFirestore.collection('notifications')).thenReturn(mockCollection);
    when(mockCollection.where('read', isEqualTo: false)).thenReturn(mockQuery);
    when(mockQuery.where('recipients', arrayContainsAny: ['all', 'test_uid']))
        .thenReturn(mockQuery);

    final mockDocs = [mockDoc]; // 通知1件
    when(mockSnapshot.docs).thenReturn(mockDocs);

    // Stream にデータを流す
    final controller = StreamController<QuerySnapshot<Map<String, dynamic>>>();
    when(mockQuery.snapshots()).thenAnswer((_) => controller.stream);

    // テスト対象ウィジェットを表示
    await tester.pumpWidget(MaterialApp(
      home: MainScreen(
          auth: mockAuth, firestore: mockFirestore, functions: mockFunctions),
    ));

    // 通知データを流してUIを更新
    controller.add(mockSnapshot);
    await tester.pump();

    // 初期タブ（施設予約）が表示されていることを確認
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);

    // 掲示板タブに切り替え
    await tester.tap(find.byIcon(Icons.message));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.message), findsOneWidget);

    // マイページタブに切り替え
    await tester.tap(find.byIcon(Icons.home));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.home), findsOneWidget);

    // 通知タブに切り替え（StreamBuilder内にバッジが表示される）
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications), findsOneWidget);

    // クリーンアップ
    await controller.close();
  });
}
