import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reservation_app/reservation_tab.dart'; // ← 正しいファイルに修正
import 'reservation_tab_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  User,
  DocumentSnapshot,
  DocumentReference,
  CollectionReference,
  QuerySnapshot,
  Query,
  QueryDocumentSnapshot,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockUser mockUser;
  late MockDocumentSnapshot<Map<String, dynamic>> mockUserSnapshot;
  late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
  late MockCollectionReference<Map<String, dynamic>> mockUserCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockFacilitySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockFacilityDoc;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockUser = MockUser();
    mockUserSnapshot = MockDocumentSnapshot();
    mockUserDocRef = MockDocumentReference();
    mockUserCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockFacilitySnapshot = MockQuerySnapshot();
    mockFacilityDoc = MockQueryDocumentSnapshot();

    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('test_uid');

    when(mockFirestore.collection('users')).thenReturn(mockUserCollection);
    when(mockUserCollection.doc('test_uid')).thenReturn(mockUserDocRef);
    when(mockUserDocRef.get()).thenAnswer((_) async => mockUserSnapshot);
    when(mockUserSnapshot.data()).thenReturn({'apartment': 'apt_001'});

    final mockFacilityCollection =
        MockCollectionReference<Map<String, dynamic>>();
    when(mockFirestore.collection('facilities'))
        .thenReturn(mockFacilityCollection);
    when(mockFacilityCollection.where('apartment_id', isEqualTo: 'apt_001'))
        .thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockFacilitySnapshot);
    when(mockFacilitySnapshot.docs).thenReturn([mockFacilityDoc]);
    when(mockFacilityDoc.id).thenReturn('facility_1');
    when(mockFacilityDoc.data()).thenReturn({
      'name': 'ジム',
      'price': 1000,
      'image': null,
    });
  });

  testWidgets('施設名と金額が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReservationTab(
          auth: mockAuth,
          firestore: mockFirestore,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('施設予約'), findsOneWidget);
    expect(find.text('ジム'), findsOneWidget);
    expect(find.text('利用金額: 1000円'), findsOneWidget);
  });
}
