import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndCheckLogin();
  }

  Future<void> _initializeAndCheckLogin() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final role = userDoc.data()?['role'] as String?;

        if (!mounted) return;

        if (role == 'CompanyAdmin') {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else if (role == 'BuildingAdmin') {
          Navigator.pushReplacementNamed(context, '/operator_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/main');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        // 🔽 ログイン画面に遷移する前にエラー表示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ログイン状態の確認中にエラーが発生しました。\n${_translateError(e.toString())}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );

        // 少し時間を置いてからログイン画面に遷移
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  // 🔽 エラー内容を簡易的に日本語に翻訳
  String _translateError(String error) {
    if (error.contains('network-request-failed')) {
      return 'ネットワークに接続できません。接続を確認してください。';
    } else if (error.contains('permission-denied')) {
      return 'データベースの読み取り権限がありません。';
    } else if (error.contains('user-not-found')) {
      return 'ユーザー情報が見つかりません。';
    } else {
      return '原因不明のエラーが発生しました。';
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
