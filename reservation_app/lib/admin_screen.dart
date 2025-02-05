import 'package:flutter/material.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('管理者画面')),
      body: const Center(
        child: Text('管理者用ダッシュボード'),
      ),
    );
  }
}
