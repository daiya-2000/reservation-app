import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mockito/annotations.dart';
import 'dart:async';

import 'package:reservation_app/profile_screen.dart';
import 'profile_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  QueryDocumentSnapshot,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
  late MockCollectionReference<Map<String, dynamic>> mockApartmentsCollection;
  late MockDocumentReference<Map<String, dynamic>> mockUserDoc;
  late MockQuerySnapshot<Map<String, dynamic>> mockApartmentSnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockApartmentDoc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockUsersCollection = MockCollectionReference();
    mockApartmentsCollection = MockCollectionReference();
    mockUserDoc = MockDocumentReference();
    mockApartmentSnapshot = MockQuerySnapshot();
    mockApartmentDoc = MockQueryDocumentSnapshot();
  });

  testWidgets('プロフィール保存ボタンでFirestoreに保存される', (tester) async {
    // モック設定
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('user123');
    when(mockUser.email).thenReturn('user@example.com');

    // ユーザーデータ保存
    when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
    when(mockUsersCollection.doc('user123')).thenReturn(mockUserDoc);
    when(mockUserDoc.set(any)).thenAnswer((_) async => {});

    // アパート一覧取得
    when(mockFirestore.collection('apartments'))
        .thenReturn(mockApartmentsCollection);
    when(mockApartmentsCollection.get())
        .thenAnswer((_) async => mockApartmentSnapshot);
    when(mockApartmentSnapshot.docs).thenReturn([mockApartmentDoc]);
    when(mockApartmentDoc.id).thenReturn('apartment123');
    when(mockApartmentDoc['name']).thenReturn('テストマンション');

    // 画面表示
    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        auth: mockAuth,
        firestore: mockFirestore,
      ),
    ));

    // FutureBuilder を完了させる
    await tester.pumpAndSettle();

    // フォームに入力
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('テストマンション').last);
    await tester.pump();

    await tester.enterText(find.byType(TextField).at(0), 'テスト太郎');
    await tester.enterText(find.byType(TextField).at(1), '101');

    // 保存ボタン押下
    await tester.tap(find.text('プロフィールを保存'));
    await tester.pumpAndSettle();

    // Firestore に正しく保存されたか検証
    verify(mockUserDoc.set(argThat(
      containsPair('name', 'テスト太郎'),
    ))).called(1);
  });
}
