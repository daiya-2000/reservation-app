import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reservation_app/operator_screen.dart';

import 'operator_bulletin_board_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
])
void main() {
  group('BulletinBoardScreen Tests', () {
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockBulletinCollection;
    late MockQuery<Map<String, dynamic>> mockBulletinQuery;
    late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
    late MockQueryDocumentSnapshot<Map<String, dynamic>> mockBulletinDoc;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockBulletinCollection = MockCollectionReference<Map<String, dynamic>>();
      mockBulletinQuery = MockQuery<Map<String, dynamic>>();
      mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
      mockBulletinDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();

      // Firestoreのbulletin_postsクエリチェーン
      when(mockFirestore.collection('bulletin_posts'))
          .thenReturn(mockBulletinCollection);
      when(mockBulletinCollection.where('apartmentId', isEqualTo: 'apt1'))
          .thenReturn(mockBulletinQuery);
      when(mockBulletinQuery.orderBy('createdAt', descending: true))
          .thenReturn(mockBulletinQuery);
      when(mockBulletinQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
      when(mockQuerySnapshot.docs).thenReturn([mockBulletinDoc]);

      when(mockBulletinDoc.id).thenReturn('post1');
      when(mockBulletinDoc.data()).thenReturn({
        'title': '掲示板テスト',
        'body': 'これはテスト投稿です',
        'pdfUrl': null,
        'createdAt': Timestamp.now(),
      });
    });

    testWidgets('renders bulletin posts correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulletinBoardScreen(
              apartmentId: 'apt1',
              firestore: mockFirestore,
            ),
          ),
        ),
      );

      // 非同期処理を完了させる
      await tester.pumpAndSettle();

      // タイトルと投稿確認
      expect(find.text('掲示板'), findsOneWidget);
      expect(find.textContaining('投稿数: 1/100'), findsOneWidget);
      expect(find.text('掲示板テスト'), findsOneWidget);
      expect(find.text('これはテスト投稿です'), findsOneWidget);

      // ボタン確認
      expect(find.text('新規掲示板作成'), findsOneWidget);
    });
  });
}
