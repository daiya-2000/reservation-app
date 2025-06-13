import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';

import 'splash_screen.dart'; // ✅ 新たに追加
import 'login_screen.dart';
import 'profile_screen.dart';
import 'main_screen.dart';
import 'admin_screen.dart';
import 'operator_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseAuth.instance.authStateChanges().first;
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'マンション予約管理アプリ',
      initialRoute: '/splash', // ✅ スプラッシュを初期ルートに
      routes: {
        '/splash': (context) => const SplashScreen(), // ✅ スプラッシュルートを追加
        '/login': (context) => const LoginScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/main': (context) => const MainScreen(),
        '/admin_dashboard': (context) => const AdminScreen(),
        '/operator_dashboard': (context) => const OperatorScreen(),
      },
      locale: const Locale('ja'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', ''),
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
    );
  }
}
