import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // 追加でfirebase_options.dartのimportも必要

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
      // ✅ Firebase初期化を待つ
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
      // 何らかのエラーが起きたらログイン画面へ
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
