import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'register_screen.dart';
import 'main_screen.dart'; // 住人用メイン画面
import 'admin_screen.dart'; // 管理者画面
import 'operator_screen.dart'; // 管理人用画面

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(); // メールアドレス用
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Firebase Authenticationでログイン
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('ユーザー情報の取得に失敗しました。');
      }

      // Firestoreからユーザーのroleを取得
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('ユーザーデータが存在しません。');
      }

      final role = userDoc.data()?['role'] as String?;
      if (role == null) {
        throw Exception('ユーザーの権限が設定されていません。');
      }

      // roleに応じて画面を切り替え
      if (role == 'CompanyAdmin') {
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
      } else if (role == 'BuildingAdmin') {
        Navigator.pushReplacementNamed(context, '/operator_dashboard');
      } else {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      // エラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログイン失敗: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // メールアドレス入力
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Eメール',
              ),
            ),
            // パスワード入力
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('ログイン'),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                // アカウント作成画面へ遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegisterScreen(),
                  ),
                );
              },
              child: const Text(
                'アカウント作成はこちら',
                style: TextStyle(
                  color: Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
