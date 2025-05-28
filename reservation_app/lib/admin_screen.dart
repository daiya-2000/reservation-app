import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ApartmentManagementScreen(),
    const ManagerAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '管理会社ダッシュボード',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) async {
              if (index == 2) {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ログアウト確認'),
                    content: const Text('ログアウトしますか？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('ログアウト'),
                      ),
                    ],
                  ),
                );

                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                }
              } else {
                setState(() {
                  _selectedIndex = index;
                });
              }
            },
            backgroundColor: Colors.blue[900],
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: Colors.white70),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.apartment),
                label: Text(
                  '管理マンション一覧',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.supervisor_account),
                label: Text(
                  '管理人アカウント一覧',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.logout),
                label: Text('ログアウト',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class ApartmentManagementScreen extends StatelessWidget {
  const ApartmentManagementScreen({super.key});

  Future<String?> _getCurrentCompanyAdminId() async {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }

  Future<List<Map<String, dynamic>>> _fetchApartments() async {
    final adminId = await _getCurrentCompanyAdminId();
    if (adminId == null) return [];

    final query = await FirebaseFirestore.instance
        .collection('apartments')
        .where('companyAdminId', isEqualTo: adminId)
        .get();

    return query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  void _showLoginDialog(
      BuildContext context, Map<String, dynamic> apartment) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();

    final role = userDoc.data()?['role'];
    if (role == 'CompanyAdmin') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${apartment['name']} にログイン'),
          content: const Text('このマンションの管理者画面にログインしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  '/operator_dashboard',
                  arguments: apartment['id'],
                );
              },
              child: const Text('ログイン'),
            ),
          ],
        ),
      );
    }
  }

  void _showAddApartmentDialog(BuildContext context) async {
    final TextEditingController _nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新規マンション追加'),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'マンション名'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                if (name.isEmpty) return;

                final adminId = FirebaseAuth.instance.currentUser?.uid;
                if (adminId == null) return;

                await FirebaseFirestore.instance.collection('apartments').add({
                  'name': name,
                  'companyAdminId': adminId,
                });

                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('マンションを追加しました')),
                );
              },
              child: const Text('作成'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // タイトルとボタンを横並びにして右寄せ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              const Text(
                '管理マンション一覧',
                style: TextStyle(fontSize: 24),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showAddApartmentDialog(context),
                child: const Text('新規マンション追加'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchApartments(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('管理しているマンションはありません。');
              }

              final apartments = snapshot.data!;
              return Expanded(
                child: ListView.builder(
                  itemCount: apartments.length,
                  itemBuilder: (context, index) {
                    final apartment = apartments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(apartment['name'] ?? '名称不明'),
                        trailing: const Icon(Icons.login),
                        onTap: () => _showLoginDialog(context, apartment),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ManagerAccountScreen extends StatelessWidget {
  const ManagerAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '管理人アカウント一覧',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
