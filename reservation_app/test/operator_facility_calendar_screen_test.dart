import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:reservation_app/operator_screen.dart';

import 'operator_facility_calendar_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  FirebaseAuth,
  FirebaseFunctions,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
  User,
])
void main() {
  group('FacilityCalendarScreen Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFunctions mockFunctions;
    late MockCollectionReference<Map<String, dynamic>> mockFacilityCollection;
    late MockQuery<Map<String, dynamic>> mockFacilityQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockFacilitySnapshot;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockFacilityDoc;
    late MockUser mockUser;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockAuth = MockFirebaseAuth();
      mockFunctions = MockFirebaseFunctions();
      mockFacilityCollection = MockCollectionReference<Map<String, dynamic>>();
      mockFacilityQuery = MockQuery<Map<String, dynamic>>();
      mockFacilitySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockFacilityDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
      mockUser = MockUser();

      // 施設取得
      when(mockFirestore.collection('facilities'))
          .thenReturn(mockFacilityCollection);
      when(mockFacilityCollection.where('apartment_id', isEqualTo: 'apt1'))
          .thenReturn(mockFacilityQuery);
      when(mockFacilityQuery.get())
          .thenAnswer((_) async => mockFacilitySnapshot);
      when(mockFacilitySnapshot.docs).thenReturn([mockFacilityDoc]);
      when(mockFacilityDoc.id).thenReturn('facility1');
      when(mockFacilityDoc.data()).thenReturn({
        'name': '会議室A',
        'price': '1000',
        'unitTime': {'value': 1, 'unit': 'h'},
      });

      // 予約取得チェーン
      final mockReservationsCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockReservationsQuery1 = MockQuery<Map<String, dynamic>>();
      final mockReservationsQuery2 = MockQuery<Map<String, dynamic>>();
      final mockReservationsQuery3 = MockQuery<Map<String, dynamic>>();
      final mockReservationsSnapshot =
          MockQuerySnapshot<Map<String, dynamic>>();

      when(mockFirestore.collection('reservations'))
          .thenReturn(mockReservationsCollection);
      when(mockReservationsCollection.where('facilityId',
              isEqualTo: 'facility1'))
          .thenReturn(mockReservationsQuery1);
      when(mockReservationsQuery1.where('date',
              isGreaterThanOrEqualTo: anyNamed('isGreaterThanOrEqualTo')))
          .thenReturn(mockReservationsQuery2);
      when(mockReservationsQuery2.where('date',
              isLessThanOrEqualTo: anyNamed('isLessThanOrEqualTo')))
          .thenReturn(mockReservationsQuery3);
      when(mockReservationsQuery3.get())
          .thenAnswer((_) async => mockReservationsSnapshot);
      when(mockReservationsSnapshot.docs).thenReturn([]);

      // unavailable_dates
      final mockUnavailableDatesCollection =
          MockCollectionReference<Map<String, dynamic>>();
      final mockUnavailableSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      final mockFacilityDocRef = MockDocumentReference<Map<String, dynamic>>();

      when(mockFacilityCollection.doc('facility1'))
          .thenReturn(mockFacilityDocRef);
      when(mockFacilityDocRef.collection('unavailable_dates'))
          .thenReturn(mockUnavailableDatesCollection);
      when(mockUnavailableDatesCollection.get())
          .thenAnswer((_) async => mockUnavailableSnapshot);
      when(mockUnavailableSnapshot.docs).thenReturn([]);

      // users
      when(mockFirestore.collection('users'))
          .thenReturn(MockCollectionReference());

      // auth
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.uid).thenReturn('user1');
    });

    testWidgets('renders and loads initial data', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FacilityCalendarScreen(
              apartmentId: 'apt1',
              firestore: mockFirestore,
              auth: mockAuth,
              functions: mockFunctions,
            ),
          ),
        ),
      );

      // 読み込み完了まで待つ
      await tester.pumpAndSettle();

      // タイトル確認
      expect(find.text('施設カレンダー'), findsOneWidget);

      // プルダウンに施設名が表示されているか確認
      expect(find.text('会議室A'), findsOneWidget);

      // ボタンが存在しているか
      expect(find.text('新規施設追加'), findsOneWidget);
      expect(find.text('施設削除'), findsOneWidget);
      expect(find.text('予約不可設定'), findsOneWidget);
      expect(find.text('予定のエクスポート'), findsOneWidget);
    });
  });
}
