import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:reservation_app/operator_screen.dart';

import 'operator_profile_screen_test.mocks.dart';

@GenerateMocks([FirebaseAuth, User])
void main() {
  group('ProfileScreen Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockUser mockUser;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockUser = MockUser();
    });

    testWidgets('表示: ログイン済みユーザーがいる場合', (WidgetTester tester) async {
      when(mockAuth.currentUser).thenReturn(mockUser);
      when(mockUser.email).thenReturn('test@example.com');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(auth: mockAuth),
          ),
        ),
      );

      expect(find.text('プロフィール'), findsOneWidget);
      expect(find.text('メール: test@example.com'), findsOneWidget);
      expect(find.text('メールアドレスを変更'), findsOneWidget);
      expect(find.text('パスワードを変更'), findsOneWidget);
    });

    testWidgets('表示: 未ログインユーザーの場合', (WidgetTester tester) async {
      when(mockAuth.currentUser).thenReturn(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProfileScreen(auth: mockAuth),
          ),
        ),
      );

      expect(find.text('ログインが必要です'), findsOneWidget);
    });
  });
}
