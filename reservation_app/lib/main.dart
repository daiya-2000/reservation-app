import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb; // Web環境を確認するためにkIsWebをインポート
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart'; // firebase_options.dart をインポート
import 'login_screen.dart'; // ログイン画面をインポート
import 'profile_screen.dart'; // プロフィール作成画面をインポート
import 'main_screen.dart'; // メイン画面をインポート
import 'admin_screen.dart'; // 管理者画面をインポート
import 'operator_screen.dart'; // 管理人用画面をインポート

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Flutterバインディングを初期化
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Firebaseを正しく初期化
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'マンション予約管理アプリ',
      initialRoute: '/login', // 初期ルートを設定
      routes: {
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/main': (context) => const MainScreen(),
        '/admin_dashboard': (context) => const AdminScreen(),
        '/operator_dashboard': (context) => const OperatorScreen(),
      },
      locale: const Locale('ja'), // 日本語ロケールを設定
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''), // 日本語対応
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue, // テーマカラーを青に設定
      ),
    );
  }
}
