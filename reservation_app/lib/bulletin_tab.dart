import 'package:flutter/material.dart';

class BulletinTab extends StatelessWidget {
  const BulletinTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掲示板'),
      ),
      body: const Center(
        child: Text('掲示板画面'),
      ),
    );
  }
}
