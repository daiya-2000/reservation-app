import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({Key? key}) : super(key: key);

  @override
  _OperatorScreenState createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    PlaceholderScreen(title: '施設カレンダー'),
    PlaceholderScreen(title: '掲示板'),
    PlaceholderScreen(title: '申請・アンケート'),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('マンション管理者ダッシュボード'),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            backgroundColor: Colors.blue[900],
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            labelType: NavigationRailLabelType.all,
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.home),
                label: const Text(
                  'ホーム',
                  style: TextStyle(
                    fontSize: 14, // 文字サイズを14に拡大
                    color: Colors.white, // 白色
                    fontWeight: FontWeight.bold, // 太字
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.calendar_today),
                label: const Text(
                  '施設カレンダー',
                  style: TextStyle(
                    fontSize: 14, // 文字サイズを14に拡大
                    color: Colors.white, // 白色
                    fontWeight: FontWeight.bold, // 太字
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.message),
                label: const Text(
                  '掲示板',
                  style: TextStyle(
                    fontSize: 14, // 文字サイズを14に拡大
                    color: Colors.white, // 白色
                    fontWeight: FontWeight.bold, // 太字
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.note),
                label: const Text(
                  '申請・アンケート',
                  style: TextStyle(
                    fontSize: 14, // 文字サイズを14に拡大
                    color: Colors.white, // 白色
                    fontWeight: FontWeight.bold, // 太字
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.account_circle),
                label: const Text(
                  'アカウント',
                  style: TextStyle(
                    fontSize: 14, // 文字サイズを14に拡大
                    color: Colors.white, // 白色
                    fontWeight: FontWeight.bold, // 太字
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDashboardCard(
            title: '施設予約状況表示',
            buttonText: 'もっと見る',
            onPressed: () {},
          ),
          const SizedBox(height: 16),
          _buildDashboardCard(
            title: '住人の新規申請表示',
            buttonText: 'もっと見る',
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.purple),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    color: Colors.purple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountScreen extends StatelessWidget {
  const AccountScreen({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchResidents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final apartmentId = userDoc['apartment'];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('apartment', isEqualTo: apartmentId)
        .where('role', isEqualTo: 'Resident')
        .get();

    return querySnapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  Future<void> _createResidentAccount(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final apartmentId = userDoc['apartment'];

    final TextEditingController roomNumberController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新規住人アカウント作成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: roomNumberController,
                decoration: const InputDecoration(labelText: '部屋番号'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final UserCredential userCredential = await FirebaseAuth
                      .instance
                      .createUserWithEmailAndPassword(
                    email: '${roomNumberController.text.trim()}@example.com',
                    password: passwordController.text.trim(),
                  );

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userCredential.user!.uid)
                      .set({
                    'name': roomNumberController.text.trim(),
                    'email': '${roomNumberController.text.trim()}@example.com',
                    'roomNumber': roomNumberController.text.trim(),
                    'role': 'Resident',
                    'apartment': apartmentId,
                  });

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('住人アカウントを作成しました。')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              },
              child: const Text('作成ボタン'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showResidentDialog(
      BuildContext context, Map<String, dynamic> resident) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('住人情報'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ユーザー名: ${resident['name']}'),
              const SizedBox(height: 8),
              Text('部屋番号: ${resident['roomNumber']}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('キャンセル'),
            ),
            OutlinedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(resident['id'])
                      .delete();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('住人を削除しました。')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: $e')),
                  );
                }
              },
              child: const Text('削除ボタン'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('住人アカウント'),
        actions: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: OutlinedButton(
              onPressed: () {
                _createResidentAccount(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.purple),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '新規住人アカウント作成',
                style: TextStyle(
                  color: Colors.purple,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchResidents(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text('住人情報が見つかりませんでした。'));
          }

          final residents = snapshot.data!;

          return ListView.builder(
            itemCount: residents.length,
            itemBuilder: (context, index) {
              final resident = residents[index];
              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(resident['name'] ?? '名前不明'),
                  subtitle: Text('部屋番号: ${resident['roomNumber'] ?? '不明'}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    _showResidentDialog(context, resident);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;

  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
