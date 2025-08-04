import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:reservation_app/facility_detail_screen.dart';

import 'facility_detail_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  User,
  CollectionReference,
  DocumentReference,
  QuerySnapshot,
  Query,
])
void main() {
  group('FacilityDetailScreen tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocument;
    late MockCollectionReference<Map<String, dynamic>>
        mockUnavailableDatesCollection;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocument = MockDocumentReference<Map<String, dynamic>>();
      mockUnavailableDatesCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockReservationQuery = MockQuery<Map<String, dynamic>>(); // 追加！

      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('test_uid');
      when(mockUser.email).thenReturn('test@example.com');

      when(mockFirestore.collection(any)).thenReturn(mockCollection);
      when(mockCollection.doc(any)).thenReturn(mockDocument);
      when(mockDocument.collection('unavailable_dates'))
          .thenReturn(mockUnavailableDatesCollection);

      // unavailable_dates.get()
      when(mockUnavailableDatesCollection.get())
          .thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([]);

      // 🔽 予約コレクションの where クエリ対応
      when(mockCollection.where(any, isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockReservationQuery);
      when(mockReservationQuery.where(any, isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockReservationQuery);
      when(mockReservationQuery.get())
          .thenAnswer((_) async => mockQuerySnapshot);
    });

    testWidgets('renders with loading spinner initially',
        (WidgetTester tester) async {
      final Map<String, dynamic> facility = {
        'id': 'facility1',
        'name': 'テスト施設',
        'image': null,
        'price': 1000,
        'unitTime': {'value': 1, 'unit': 'h'},
      };

      await tester.pumpWidget(
        MaterialApp(
          home: FacilityDetailScreen(
            facility: facility,
            firestore: mockFirestore,
            auth: mockAuth,
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('施設詳細'), findsOneWidget);
    });
  });
}
