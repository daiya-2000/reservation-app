import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:reservation_app/splash_screen.dart';
import 'splash_screen_test.mocks.dart';

@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseFirestore,
  DocumentSnapshot,
  NavigatorObserver,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseFirestore mockFirestore;
  late MockDocumentSnapshot<Map<String, dynamic>> mockDocSnapshot;
  late MockNavigatorObserver mockObserver;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockFirestore = MockFirebaseFirestore();
    mockDocSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
    mockObserver = MockNavigatorObserver();

    // 🔧 navigator にスタブ追加
    when(mockObserver.navigator).thenReturn(null);
  });

  Future<void> pumpSplashScreen(WidgetTester tester) async {
    // 🔧 MaterialApp を初期化前にリセット
    await tester.pumpWidget(const SizedBox());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SplashScreen(
            auth: mockAuth,
            firestore: mockFirestore,
            initializeApp: () async => FakeFirebaseApp(),
          ),
        ),
        navigatorObservers: [mockObserver],
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (_) =>
                Scaffold(body: Text('Navigated to ${settings.name}')),
            settings: settings,
          );
        },
      ),
    );

    await tester.pump(); // 初期 build
    await tester.pump(const Duration(seconds: 1)); // 初期処理待ち
    await tester.pumpAndSettle(); // 遷移＆SnackBar 完了待ち
  }

  testWidgets('ログインなし → /login に遷移', (tester) async {
    when(mockAuth.currentUser).thenReturn(null);

    await pumpSplashScreen(tester);

    expect(find.text('Navigated to /login'), findsOneWidget);
  });

  testWidgets('CompanyAdmin → /admin_dashboard に遷移', (tester) async {
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('user123');
    when(mockFirestore.collection('users'))
        .thenReturn(FakeCollection(mockDocSnapshot));
    when(mockDocSnapshot.data()).thenReturn({'role': 'CompanyAdmin'});

    await pumpSplashScreen(tester);

    expect(find.text('Navigated to /admin_dashboard'), findsOneWidget);
  });

  testWidgets('BuildingAdmin → /operator_dashboard に遷移', (tester) async {
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('user456');
    when(mockFirestore.collection('users'))
        .thenReturn(FakeCollection(mockDocSnapshot));
    when(mockDocSnapshot.data()).thenReturn({'role': 'BuildingAdmin'});

    await pumpSplashScreen(tester);

    expect(find.text('Navigated to /operator_dashboard'), findsOneWidget);
  });

  testWidgets('その他のロール → /main に遷移', (tester) async {
    when(mockAuth.currentUser).thenReturn(mockUser);
    when(mockUser.uid).thenReturn('user789');
    when(mockFirestore.collection('users'))
        .thenReturn(FakeCollection(mockDocSnapshot));
    when(mockDocSnapshot.data()).thenReturn({'role': 'Resident'});

    await pumpSplashScreen(tester);

    expect(find.text('Navigated to /main'), findsOneWidget);
  });

  testWidgets('例外発生時 → SnackBar 表示 & /login に遷移', (tester) async {
    when(mockAuth.currentUser).thenThrow(Exception('network-request-failed'));

    await pumpSplashScreen(tester);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('ネットワークに接続できません'), findsOneWidget);
    expect(find.text('Navigated to /login'), findsOneWidget);
  });
}

// --- FirebaseApp のモック ---
class FakeFirebaseApp extends Fake implements FirebaseApp {}

// --- Firestore Collection → Document → get() チェーンを再現 ---
class FakeCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final DocumentSnapshot<Map<String, dynamic>> docSnapshot;
  FakeCollection(this.docSnapshot);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? id]) =>
      FakeDocument(docSnapshot);
}

class FakeDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final DocumentSnapshot<Map<String, dynamic>> snapshot;
  FakeDocument(this.snapshot);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
          [GetOptions? options]) async =>
      snapshot;
}
