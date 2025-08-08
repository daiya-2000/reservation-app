import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reservation_app/bulletin_tab.dart';

import 'bulletin_tab_test.mocks.dart';

@GenerateMocks([
  FirebaseFirestore,
  CollectionReference,
  Query,
  QuerySnapshot,
  QueryDocumentSnapshot,
])
void main() {
  late MockFirebaseFirestore mockFirestore;
  late MockCollectionReference<Map<String, dynamic>> mockCollection;
  late MockQuery<Map<String, dynamic>> mockQuery;
  late MockQuerySnapshot<Map<String, dynamic>> mockQuerySnapshot;
  late MockQueryDocumentSnapshot<Map<String, dynamic>> mockDocument;

  setUp(() {
    mockFirestore = MockFirebaseFirestore();
    mockCollection = MockCollectionReference();
    mockQuery = MockQuery();
    mockQuerySnapshot = MockQuerySnapshot();
    mockDocument = MockQueryDocumentSnapshot();

    when(mockFirestore.collection('bulletin_posts')).thenReturn(mockCollection);
    when(mockCollection.orderBy('createdAt', descending: true))
        .thenReturn(mockQuery);
    when(mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
    when(mockQuerySnapshot.docs).thenReturn([mockDocument]);

    when(mockDocument.data()).thenReturn({
      'title': 'タイトル1',
      'body': '本文1',
      'createdAt': Timestamp.fromDate(DateTime(2024, 8, 1, 10, 30)),
      'pdfUrl': null,
    });
  });

  testWidgets('掲示板に投稿が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BulletinTab(firestore: mockFirestore),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('掲示板'), findsOneWidget);
    expect(find.text('タイトル1'), findsOneWidget);
    expect(find.textContaining('本文1'), findsOneWidget);
    expect(find.textContaining('投稿日: 2024/08/01 10:30'), findsOneWidget);
  });
}
