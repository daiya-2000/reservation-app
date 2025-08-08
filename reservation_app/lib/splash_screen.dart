import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

class SplashScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final Future<FirebaseApp> Function() initializeApp;

  const SplashScreen({
    Key? key,
    required this.auth,
    required this.firestore,
    required this.initializeApp,
  }) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAndCheckLogin();
  }

  Future<void> _initializeAndCheckLogin() async {
    try {
      // Firebase 初期化（常に inject された initializeApp を使う）
      await widget.initializeApp();

      final user = widget.auth.currentUser;

      if (user != null) {
        final userDoc =
            await widget.firestore.collection('users').doc(user.uid).get();

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

        await Future.delayed(const Duration(seconds: 1));
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

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
