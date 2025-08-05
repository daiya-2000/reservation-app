import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const LoginScreen({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final user = widget.auth.currentUser;
    if (user != null) {
      await _navigateToRoleBasedScreen(user);
    }
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showErrorMessage('メールアドレスとパスワードを入力してください');
      return;
    }

    try {
      final userCredential = await widget.auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        _showErrorMessage('ログインに失敗しました。もう一度お試しください。');
        return;
      }

      await _navigateToRoleBasedScreen(user);
    } on FirebaseAuthException catch (e) {
      _showErrorMessage(_getErrorMessageFromCode(e.code));
    } catch (e) {
      _showErrorMessage('予期しないエラーが発生しました。もう一度お試しください。');
    }
  }

  String _getErrorMessageFromCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません。';
      case 'user-disabled':
        return 'このユーザーアカウントは無効化されています。';
      case 'user-not-found':
        return '登録されていないメールアドレスです。';
      case 'wrong-password':
        return 'パスワードが間違っています。';
      default:
        return 'ログインに失敗しました。 ($code)';
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _navigateToRoleBasedScreen(User user) async {
    final userDoc =
        await widget.firestore.collection('users').doc(user.uid).get();

    final role = userDoc.data()?['role'] as String?;
    if (!mounted) return;

    switch (role) {
      case 'CompanyAdmin':
        Navigator.pushReplacementNamed(context, '/admin_dashboard');
        break;
      case 'BuildingAdmin':
        Navigator.pushReplacementNamed(context, '/operator_dashboard');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/main');
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
            TextField(
              key: const Key('emailField'),
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Eメール'),
            ),
            TextField(
              key: const Key('passwordField'),
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'パスワード'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('loginButton'),
              onPressed: _login,
              child: const Text('ログイン'),
            ),
          ],
        ),
      ),
    );
  }
}
