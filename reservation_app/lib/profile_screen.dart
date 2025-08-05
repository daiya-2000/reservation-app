import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const ProfileScreen({
    Key? key,
    required this.firestore,
    required this.auth,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  String? _selectedApartment;

  Future<void> _saveProfile() async {
    if (_selectedApartment == null ||
        _nameController.text.isEmpty ||
        _roomNumberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('すべての項目を入力してください。'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final user = widget.auth.currentUser;
      if (user != null) {
        await widget.firestore.collection('users').doc(user.uid).set({
          'apartment': _selectedApartment,
          'name': _nameController.text.trim(),
          'roomNumber': _roomNumberController.text.trim(),
          'email': user.email,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('プロフィールが保存されました。'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('プロフィールの保存に失敗しました。しばらくしてからもう一度お試しください。'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール作成')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<QuerySnapshot>(
              future: widget.firestore.collection('apartments').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final apartments = snapshot.data!.docs;
                return DropdownButton<String>(
                  value: _selectedApartment,
                  hint: const Text('マンションを選択してください'),
                  onChanged: (value) {
                    setState(() {
                      _selectedApartment = value;
                    });
                  },
                  items: apartments.map((apartment) {
                    return DropdownMenuItem<String>(
                      value: apartment.id,
                      child: Text(apartment['name']),
                    );
                  }).toList(),
                );
              },
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '氏名'),
            ),
            TextField(
              controller: _roomNumberController,
              decoration: const InputDecoration(labelText: '部屋番号'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('プロフィールを保存'),
            ),
          ],
        ),
      ),
    );
  }
}
