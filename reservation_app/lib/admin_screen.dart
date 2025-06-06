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
                label: Text('管理マンション一覧',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.supervisor_account),
                label: Text('管理人アカウント一覧',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
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

class ApartmentManagementScreen extends StatefulWidget {
  const ApartmentManagementScreen({super.key});

  @override
  State<ApartmentManagementScreen> createState() =>
      _ApartmentManagementScreenState();
}

class _ApartmentManagementScreenState extends State<ApartmentManagementScreen> {
  List<Map<String, dynamic>> _apartments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // context を使えるように post-frame callback に移動
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchApartments(context: context);
    });
  }

  Future<void> _fetchApartments({required BuildContext context}) async {
    try {
      final adminId = FirebaseAuth.instance.currentUser?.uid;
      if (adminId == null) throw Exception('管理者情報が取得できませんでした');

      final query = await FirebaseFirestore.instance
          .collection('apartments')
          .where('companyAdminId', isEqualTo: adminId)
          .get();

      if (!mounted) return;

      setState(() {
        _apartments =
            query.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('マンションの取得に失敗しました: ${_translateError(e.toString())}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLoginDialog(
      BuildContext context, Map<String, dynamic> apartment) async {
    final apartmentId = apartment['id'];
    final TextEditingController nameController =
        TextEditingController(text: apartment['name']);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${apartment['name']} に対する操作'),
        content: const Text('以下の操作を選択してください：'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushNamed(context, '/operator_dashboard',
                  arguments: apartmentId);
            },
            child: const Text('ログイン'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _showEditApartmentDialog(context, apartmentId, nameController);
            },
            child: const Text('編集'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(dialogContext);
              _showDeleteApartmentDialog(context, apartmentId);
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
  }

  void _showEditApartmentDialog(BuildContext context, String apartmentId,
      TextEditingController controller) {
    final parentContext = context;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('マンション名を編集'),
        content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: '新しいマンション名')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              Navigator.pop(dialogContext); // ダイアログを先に閉じる

              if (newName.isEmpty) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('マンション名を入力してください'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('apartments')
                    .doc(apartmentId)
                    .update({'name': newName});
                await _fetchApartments(context: parentContext);
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(content: Text('マンション名を更新しました')),
                );
              } catch (e) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  SnackBar(
                    content: Text('更新に失敗しました: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  void _showDeleteApartmentDialog(BuildContext context, String apartmentId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('マンション削除の確認'),
        content: const Text('このマンションを削除しますか？元に戻せません。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance
                    .collection('apartments')
                    .doc(apartmentId)
                    .delete();
                await _fetchApartments(context: context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('マンションを削除しました')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('削除に失敗しました: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
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
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                Navigator.pop(dialogContext);

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('マンション名を入力してください'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  final adminId = FirebaseAuth.instance.currentUser?.uid;
                  if (adminId == null) throw Exception('管理者情報が取得できません');

                  await FirebaseFirestore.instance
                      .collection('apartments')
                      .add({
                    'name': name,
                    'companyAdminId': adminId,
                  });

                  await _fetchApartments(context: context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('マンションを追加しました')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'マンションの追加に失敗しました: ${_translateError(e.toString())}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              const Text('管理マンション一覧', style: TextStyle(fontSize: 24)),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showAddApartmentDialog(context),
                child: const Text('新規マンション追加'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _apartments.isEmpty
                    ? const Text('管理しているマンションはありません。')
                    : ListView.builder(
                        itemCount: _apartments.length,
                        itemBuilder: (context, index) {
                          final apartment = _apartments[index];
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

String _translateError(String error) {
  if (error.contains('network-request-failed')) {
    return 'ネットワークに接続できません。接続を確認してください。';
  } else if (error.contains('permission-denied')) {
    return '権限がありません。';
  } else if (error.contains('not-found')) {
    return '対象のデータが見つかりませんでした。';
  } else {
    return '不明なエラーが発生しました。';
  }
}
