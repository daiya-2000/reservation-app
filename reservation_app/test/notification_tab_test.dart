import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reservation_app/notification_tab.dart';
import 'notification_tab_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  DocumentReference,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockSnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDoc;
  late MockDocumentReference<Map<String, dynamic>> mockDocRef;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockQuery = MockQuery();
    mockSnapshot = MockQuerySnapshot();
    mockDoc = MockQueryDocumentSnapshot();
    mockDocRef = MockDocumentReference();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_user');

    final mockCollection = MockCollectionReference<Map<String, dynamic>>();
    when(mockFirestore.collection('notifications')).thenReturn(mockCollection);
    when(mockCollection.where('recipients',
        arrayContainsAny: ['test_user', 'all'])).thenReturn(mockQuery);
    when(mockQuery.orderBy('timestamp', descending: true))
        .thenReturn(mockQuery);

    when(mockDoc.data()).thenReturn({
      'message': 'テスト通知',
      'read': false,
      'timestamp': Timestamp.fromDate(DateTime(2024, 1, 1, 10, 30)),
    });
    when(mockDoc.reference).thenReturn(mockDocRef);
    when(mockSnapshot.docs).thenReturn([mockDoc]);

    when(mockQuery.snapshots()).thenAnswer((_) => Stream.value(mockSnapshot));
  });

  testWidgets('通知が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NotificationTab(auth: mockAuth, firestore: mockFirestore),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('テスト通知'), findsOneWidget);
    expect(find.text('2024/01/01 10:30'), findsOneWidget);
  });
}
