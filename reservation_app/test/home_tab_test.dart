import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:reservation_app/home_tab.dart';

import 'home_tab_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  FirebaseFunctions,
  User,
  DocumentSnapshot,
  DocumentReference,
  CollectionReference,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockFirebaseFunctions mockFunctions;
  late MockUser mockUser;
  late MockDocumentSnapshot<Map<String, dynamic>> mockUserSnapshot;
  late MockDocumentSnapshot<Map<String, dynamic>> mockApartmentSnapshot;
  late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
  late MockDocumentReference<Map<String, dynamic>> mockAptDocRef;
  late MockCollectionReference<Map<String, dynamic>> mockUserCollection;
  late MockCollectionReference<Map<String, dynamic>> mockAptCollection;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockFunctions = MockFirebaseFunctions();
    mockUser = MockUser();
    mockUserSnapshot = MockDocumentSnapshot();
    mockApartmentSnapshot = MockDocumentSnapshot();
    mockUserDocRef = MockDocumentReference();
    mockAptDocRef = MockDocumentReference();
    mockUserCollection = MockCollectionReference();
    mockAptCollection = MockCollectionReference();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    // Firestore: users/test_uid
    when(mockFirestore.collection('users')).thenReturn(mockUserCollection);
    when(mockUserCollection.doc('test_uid')).thenReturn(mockUserDocRef);
    when(mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
    when(mockUserSnapshot.data()).thenReturn({
      'name': 'テスト太郎',
      'roomNumber': '101',
      'apartment': 'apartment_123',
      'role': 'resident',
    });

    // Firestore: apartments/apartment_123
    when(mockFirestore.collection('apartments')).thenReturn(mockAptCollection);
    when(mockAptCollection.doc('apartment_123')).thenReturn(mockAptDocRef);
    when(mockAptDocRef.get()).thenAnswer((_) async => mockApartmentSnapshot);
    when(mockApartmentSnapshot.data()).thenReturn({'name': 'テストマンション'});
  });

  testWidgets('マイページタイトルが表示される', (WidgetTester tester) async {
    // authStateChanges にダミーの Stream を返す
    when(mockAuth.authStateChanges()).thenAnswer(
      (_) => Stream<User?>.value(mockUser),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTab(
            auth: mockAuth,
            firestore: mockFirestore,
            functions: mockFunctions,
          ),
        ),
      ),
    );

    // 非同期UIの更新をすべて待つ
    await tester.pumpAndSettle();

    expect(find.text('マイページ'), findsOneWidget);
    expect(find.text('氏名: テスト太郎'), findsOneWidget);
    expect(find.text('マンション名: テストマンション'), findsOneWidget);
  });
}
