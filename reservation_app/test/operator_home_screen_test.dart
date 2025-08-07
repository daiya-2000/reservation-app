import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:reservation_app/operator_screen.dart';

import 'operator_home_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
])
void main() {
  group('HomeScreen tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>>
        mockReservationsCollection;
    late MockCollectionReference<Map<String, dynamic>> mockUsersCollection;
    late MockQuery<Map<String, dynamic>> mockReservationsQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockReservationsSnapshot;
    late MockDocumentReference<Map<String, dynamic>> mockUserDocRef;
    late MockDocumentSnapshot<Map<String, dynamic>> mockUserDoc;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockReservationDoc;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockReservationsCollection =
          MockCollectionReference<Map<String, dynamic>>();
      mockUsersCollection = MockCollectionReference<Map<String, dynamic>>();
      mockReservationsQuery = MockQuery<Map<String, dynamic>>();
      mockReservationsSnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockUserDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockUserDoc = MockDocumentSnapshot<Map<String, dynamic>>();
      mockReservationDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // reservations コレクションのクエリチェーン
      when(mockFirestore.collection('reservations'))
          .thenReturn(mockReservationsCollection);
      when(mockReservationsCollection.where('apartmentId',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockReservationsQuery);
      when(mockReservationsQuery.where('date',
              isEqualTo: anyNamed('isEqualTo')))
          .thenReturn(mockReservationsQuery);
      when(mockReservationsQuery.get())
          .thenAnswer((_) async => mockReservationsSnapshot);
      when(mockReservationsSnapshot.docs).thenReturn([mockReservationDoc]);

      // reservation doc データ
      when(mockReservationDoc.data()).thenReturn({
        'times': ['09:00'],
        'userId': 'user123',
      });

      // users ドキュメント
      when(mockFirestore.collection('users')).thenReturn(mockUsersCollection);
      when(mockUsersCollection.doc('user123')).thenReturn(mockUserDocRef);
      when(mockUserDocRef.get()).thenAnswer((_) async => mockUserDoc);
      when(mockUserDoc.exists).thenReturn(true);
      when(mockUserDoc.data()).thenReturn({
        'roomNumber': '101',
        'name': '佐藤',
      });
    });

    testWidgets(
        'HomeScreen renders and shows reservation dialog on button press',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HomeScreen(
            apartmentId: 'apt1',
            firestore: mockFirestore,
          ),
        ),
      );

      // アプリバーのタイトル確認
      expect(find.text('ホーム'), findsOneWidget);

      // 「もっと見る」ボタンタップでダイアログ表示
      await tester.tap(find.text('もっと見る'));
      await tester.pumpAndSettle();

      // ダイアログの内容検証
      expect(find.text('本日と翌日の予約状況'), findsOneWidget);
      expect(find.textContaining('101号室 佐藤'), findsNWidgets(2));
      expect(find.text('閉じる'), findsOneWidget);

      // ダイアログ閉じる
      await tester.tap(find.text('閉じる'));
      await tester.pumpAndSettle();

      // ダイアログが閉じられたことを確認
      expect(find.text('本日と翌日の予約状況'), findsNothing);
    });
  });
}
