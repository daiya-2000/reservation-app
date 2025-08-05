import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:reservation_app/login_screen.dart';
import 'login_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  UserCredential,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  late MockUserCredential mockUserCredential;
  late MockDocumentSnapshot<Map<String, dynamic>> mockUserDoc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockUserCredential = MockUserCredential();
    mockUserDoc = MockDocumentSnapshot();
    when(mockAuth.currentUser).thenReturn(null);
  });

  testWidgets('shows error if email or password is empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: mockFirestore),
      ),
    );

    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pump(); // wait for SnackBar

    expect(find.text('メールアドレスとパスワードを入力してください'), findsOneWidget);
  });

  testWidgets('calls login and navigates on success', (tester) async {
    when(mockAuth.signInWithEmailAndPassword(
            email: anyNamed('email'), password: anyNamed('password')))
        .thenAnswer((_) async => mockUserCredential);
    when(mockUserCredential.user).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('uid123');
    when(mockAuth.currentUser).thenReturn(mockUser);

    final mockCollection = MockCollectionReference<Map<String, dynamic>>();
    final mockDocRef = MockDocumentReference<Map<String, dynamic>>();
    mockUserDoc = MockDocumentSnapshot<Map<String, dynamic>>();

    when(mockFirestore.collection('users')).thenReturn(mockCollection);
    when(mockCollection.doc('uid123')).thenReturn(mockDocRef);
    when(mockDocRef.get()).thenAnswer((_) async => mockUserDoc);
    when(mockUserDoc.exists).thenReturn(true);
    when(mockUserDoc.data()).thenReturn({'role': 'CompanyAdmin'});

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(auth: mockAuth, firestore: mockFirestore),
        routes: {
          '/admin_dashboard': (_) => const Scaffold(body: Text('Admin')),
        },
      ),
    );

    await tester.enterText(
        find.byKey(const Key('emailField')), 'test@example.com');
    await tester.enterText(
        find.byKey(const Key('passwordField')), 'password123');
    await tester.tap(find.byKey(const Key('loginButton')));
    await tester.pumpAndSettle();

    expect(find.text('Admin'), findsOneWidget);
  });
}
