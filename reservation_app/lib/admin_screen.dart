import 'package:cloud_functions/cloud_functions.dart';
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
    const ProfileScreen(),
    const SizedBox(), // ログアウトはダミー
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ─── OperatorScreen と同じ AppBar ─────────────
      appBar: AppBar(
        title: const Text(
          'マンション管理会社ダッシュボード',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
        centerTitle: true, // タイトル中央寄せ
        automaticallyImplyLeading: false, // 戻る矢印を消す
      ),
      body: Row(
        children: [
          // ─── 同じデザインの NavigationRail ────────────
          NavigationRail(
            backgroundColor: Colors.blue[900],
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) async {
              if (index == 3) {
                // ログアウト処理
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('ログアウト確認'),
                    content: const Text('ログアウトしますか？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('キャンセル')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('ログアウト')),
                    ],
                  ),
                );
                if (ok == true) {
                  await FirebaseAuth.instance.signOut();
                  Navigator.of(context).pushReplacementNamed('/login');
                }
                return;
              }
              setState(() => _selectedIndex = index);
            },
            // ─── アイコン＆ラベルの色や表示方法 ─────────
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
                      fontWeight: FontWeight.bold),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.supervisor_account),
                label: Text(
                  '管理人アカウント一覧',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person),
                label: Text(
                  'プロフィール',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.logout),
                label: Text(
                  'ログアウト',
                  style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          // ─── ページ本体 ─────────────────────────────
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

class ManagerAccountScreen extends StatefulWidget {
  const ManagerAccountScreen({super.key});

  @override
  State<ManagerAccountScreen> createState() => _ManagerAccountScreenState();
}

class _ManagerAccountScreenState extends State<ManagerAccountScreen> {
  List<Map<String, dynamic>> _managers = [];
  bool _isLoading = true;
  final Map<String, String> _apartmentNames = {}; // apartmentId -> name

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchBuildingAdmins();
    });
  }

  Future<void> _fetchBuildingAdmins() async {
    setState(() => _isLoading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('ログイン情報が取得できません');

      final companyAdminId = currentUser.uid;
      final apartmentQuery = await FirebaseFirestore.instance
          .collection('apartments')
          .where('companyAdminId', isEqualTo: companyAdminId)
          .get();

      final apartmentIds = <String>[];
      _apartmentNames.clear();
      for (var doc in apartmentQuery.docs) {
        apartmentIds.add(doc.id);
        _apartmentNames[doc.id] = doc.data()['name'] ?? '名称不明';
      }

      if (apartmentIds.isEmpty) {
        setState(() {
          _managers = [];
          _isLoading = false;
        });
        return;
      }

      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'BuildingAdmin')
          .where('apartment', whereIn: apartmentIds)
          .get();

      setState(() {
        _managers =
            userQuery.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('管理人アカウントの取得に失敗しました: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// ← ここを必ずクラス内に追加！
  void _showCreateManagerDialog(BuildContext parentContext) {
    final nameController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedApartmentId;

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('新規管理人アカウント作成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名前'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'パスワード'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'マンションを選択'),
                items: _apartmentNames.entries
                    .map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ))
                    .toList(),
                onChanged: (v) => selectedApartmentId = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final password = passwordController.text.trim();
                final apartmentId = selectedApartmentId;
                if (name.isEmpty || password.isEmpty || apartmentId == null) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    const SnackBar(
                      content: Text('全ての項目を入力してください'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext);

                try {
                  final functions =
                      FirebaseFunctions.instanceFor(region: 'us-central1');
                  final callable =
                      functions.httpsCallable('createManagerAccount');
                  final result = await callable.call({
                    'name': name,
                    'email': '$name@example.com',
                    'password': password,
                    'apartmentId': apartmentId,
                  });
                  if (result.data['success'] == true) {
                    await _fetchBuildingAdmins();
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('管理人アカウントを作成しました')),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(parentContext).showSnackBar(
                    SnackBar(content: Text('作成に失敗しました: $e')),
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

  void _showManagerDetailDialog(
      BuildContext parentContext, Map<String, dynamic> manager) {
    final apartmentName = _apartmentNames[manager['apartment']] ?? '名称不明';

    showDialog(
      context: parentContext,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('管理人情報'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ユーザー名: ${manager['name']}'),
              const SizedBox(height: 8),
              Text('メールアドレス: ${manager['email']}'),
              const SizedBox(height: 8),
              Text('マンション: $apartmentName'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            OutlinedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final uid = manager['id'] as String;
                try {
                  final functions =
                      FirebaseFunctions.instanceFor(region: 'us-central1');
                  final callable =
                      functions.httpsCallable('deleteManagerAccount');
                  final result = await callable.call({'uid': uid});

                  if (result.data['success'] == true) {
                    // 2) データ再取得
                    await _fetchBuildingAdmins();

                    // 3) 次のフレームでスナックバーを表示
                    if (!mounted) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('管理人アカウントを削除しました。'),
                        ),
                      );
                    });
                  }
                } catch (e) {
                  if (!mounted) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('削除に失敗しました: $e')),
                    );
                  });
                }
              },
              child: const Text('削除'),
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
          // タイトル & 作成ボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              const Text(
                '管理人アカウント一覧',
                style: TextStyle(fontSize: 24),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showCreateManagerDialog(context),
                child: const Text('新規アカウント作成'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _managers.isEmpty
                    ? const Center(child: Text('管理しているマンションの管理人が見つかりません'))
                    : ListView.builder(
                        itemCount: _managers.length,
                        itemBuilder: (context, index) {
                          final manager = _managers[index];
                          final apartmentName =
                              _apartmentNames[manager['apartment']] ?? '名称不明';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                vertical: 8, horizontal: 4),
                            child: ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(manager['name'] ?? '名前未設定'),
                              subtitle: Text(manager['email'] ?? ''),
                              trailing: const Icon(Icons.arrow_forward_ios),
                              onTap: () =>
                                  _showManagerDetailDialog(context, manager),
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインが必要です'));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // タイトル Row（他画面と同じデザイン）
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Spacer(),
              Text(
                'プロフィール',
                style: TextStyle(fontSize: 24),
              ),
              Spacer(),
              // プロフィールには右側ボタン無しなので空の SizedBox
              SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),

          // メール表示
          Center(
            child: Text(
              'メールアドレス: ${user.email}',
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(height: 24),

          // メールアドレス変更
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('メールアドレスを変更'),
              onTap: () => _changeEmail(context),
            ),
          ),
          const SizedBox(height: 12),

          // パスワード変更
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('パスワードを変更'),
              onTap: () => _changePassword(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmail(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

    // 1) 再認証ダイアログ
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メール変更'),
        content: TextField(
          controller: pwdCtl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '現在のパスワード'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('次へ')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: pwdCtl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

    // 2) 新メール入力ダイアログ
    await showDialog<void>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('新しいメールアドレス'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: newCtl,
                decoration: const InputDecoration(labelText: '新メール')),
            TextField(
                controller: confirmCtl,
                decoration: const InputDecoration(labelText: '確認用')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtl.text.trim() != confirmCtl.text.trim()) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('メールが一致しません')));
                return;
              }
              try {
                await user.verifyBeforeUpdateEmail(newCtl.text.trim());
                Navigator.pop(ctx2);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('確認メールを送信しました')));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('エラー: $e')));
              }
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

    // 1) 再認証ダイアログ
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パスワード変更'),
        content: TextField(
          controller: pwdCtl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '現在のパスワード'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('次へ')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: pwdCtl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

    // 2) 新パスワード入力ダイアログ
    await showDialog<void>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('新しいパスワード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: newCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新パスワード')),
            TextField(
                controller: confirmCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認用パスワード')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtl.text.trim() != confirmCtl.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードが一致しません')));
                return;
              }
              try {
                await user.updatePassword(newCtl.text.trim());
                Navigator.pop(ctx2);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードを更新しました')));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('エラー: $e')));
              }
            },
            child: const Text('保存'),
          ),
        ],
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
