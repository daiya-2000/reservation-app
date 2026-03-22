import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;
  final FirebaseFunctions functions;

  const AdminScreen({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ?? FirebaseFunctions.instance,
        super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  static const _shellBackground = Color(0xFFF6F8FB);
  static const _shellPrimary = Color(0xFF0C5D78);
  static const _shellPrimaryDark = Color(0xFF083F53);

  int _selectedIndex = 0;

  late final FirebaseFirestore firestore;
  late final FirebaseAuth auth;
  late final FirebaseFunctions functions;

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    firestore = widget.firestore;
    auth = widget.auth;
    functions = widget.functions;

    _pages = [
      ApartmentManagementScreen(firestore: firestore, auth: auth),
      ManagerAccountScreen(
        firestore: firestore,
        auth: auth,
        functions: functions,
      ),
      ProfileScreen(auth: auth),
      const SizedBox(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      _AdminNavItem(
        label: '管理マンション一覧',
        hint: 'マンション管理',
        icon: Icons.apartment_rounded,
      ),
      _AdminNavItem(
        label: '管理人アカウント一覧',
        hint: 'アカウント管理',
        icon: Icons.groups_rounded,
      ),
      _AdminNavItem(
        label: 'プロフィール',
        hint: 'アカウント設定',
        icon: Icons.person_rounded,
      ),
      _AdminNavItem(
        label: 'ログアウト',
        hint: 'セッション終了',
        icon: Icons.logout_rounded,
      ),
    ];

    return Scaffold(
      backgroundColor: _shellBackground,
      body: Row(
        children: [
          Container(
            width: 272,
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _shellPrimaryDark,
                  _shellPrimary,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x332B839D),
                          Color(0x222A6C84),
                        ],
                      ),
                      border: Border.all(color: const Color(0x255DE1FF)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Admin',
                          style: TextStyle(
                            color: Color(0xFFAAD5E5),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'マンション管理会社\nダッシュボード',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            height: 1.08,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 14),
                        Text(
                          '管理マンション、管理人アカウント、プロフィール設定を1つの画面から管理します。',
                          style: TextStyle(
                            color: Color(0xFFD5EBF3),
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Text(
                      'MAIN MENU',
                      style: TextStyle(
                        color: Color(0xFFA8D4E4),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: ListView.separated(
                      itemCount: destinations.length,
                      padding: EdgeInsets.zero,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = destinations[index];
                        return _AdminSidebarButton(
                          item: item,
                          selected: _selectedIndex == index,
                          onTap: () async {
                            if (index == 3) {
                              final ok = await showDialog<bool>(
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
                              if (ok == true) {
                                await auth.signOut();
                                if (!mounted) return;
                                Navigator.of(context).pushReplacementNamed('/login');
                              }
                              return;
                            }
                            setState(() => _selectedIndex = index);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: _shellBackground,
              child: _pages[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminNavItem {
  final String label;
  final String hint;
  final IconData icon;

  const _AdminNavItem({
    required this.label,
    required this.hint,
    required this.icon,
  });
}

class _AdminSidebarButton extends StatelessWidget {
  final _AdminNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _AdminSidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: selected ? const Color(0x2AFFFFFF) : Colors.transparent,
        border: Border.all(
          color: selected ? const Color(0x3AFFFFFF) : Colors.transparent,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : const Color(0x1FFFFFFF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    item.icon,
                    color: selected
                        ? _AdminScreenState._shellPrimary
                        : Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.hint,
                        style: const TextStyle(
                          color: Color(0xD8D2EAF2),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ApartmentManagementScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const ApartmentManagementScreen({
    super.key,
    required this.firestore,
    required this.auth,
  });

  @override
  State<ApartmentManagementScreen> createState() =>
      _ApartmentManagementScreenState();
}

class _ApartmentManagementScreenState extends State<ApartmentManagementScreen> {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  List<Map<String, dynamic>> _apartments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchApartments(context: context);
    });
  }

  Future<void> _fetchApartments({required BuildContext context}) async {
    try {
      final adminId = widget.auth.currentUser?.uid;
      if (adminId == null) throw Exception('管理者情報が取得できませんでした');

      final query = await widget.firestore
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
      setState(() => _isLoading = false);
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
              Navigator.pop(dialogContext);

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
                await widget.firestore
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
                await widget.firestore
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
                  final adminId = widget.auth.currentUser?.uid;
                  if (adminId == null) throw Exception('管理者情報が取得できません');

                  await widget.firestore.collection('apartments').add({
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

  String _translateError(String message) {
    if (message.contains('permission-denied')) {
      return '権限がありません';
    }
    return message;
  }

  Widget _buildApartmentCard(
    BuildContext context,
    Map<String, dynamic> apartment,
  ) {
    final apartmentName = apartment['name']?.toString().trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showLoginDialog(context, apartment),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: _primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          apartmentName == null || apartmentName.isEmpty
                              ? '名称不明'
                              : apartmentName,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'クリックするとログイン、編集、削除の操作を開きます。',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE7F5FB),
                  Colors.white,
                  Color(0xFFF4FBFE),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final infoColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x14004D64),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'APARTMENT PORTFOLIO',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '管理マンションを\n一覧管理できます。',
                      style: TextStyle(
                        color: _textStrong,
                        fontSize: 34,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '管理会社に紐づくマンションの確認、追加、ログイン、編集、削除をこの画面から行えます。',
                      style: TextStyle(
                        color: Color(0xFF5A6973),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddApartmentDialog(context),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('新規マンション追加'),
                      style: FilledButton.styleFrom(
                        foregroundColor: _primary,
                        backgroundColor: const Color(0xFFD9EDF7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                );

                final summaryPanel = Container(
                  width: compact ? double.infinity : 280,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0x140C5D78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '運用サマリー',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSummaryRow(
                        label: '管理棟数',
                        value: '${_apartments.length}件',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'カードをクリックすると対象マンションの操作メニューを開きます。',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoColumn,
                      const SizedBox(height: 22),
                      summaryPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoColumn),
                    const SizedBox(width: 24),
                    summaryPanel,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_apartments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 40,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.domain_add_rounded,
                    size: 52,
                    color: _primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '管理しているマンションはありません。',
                    style: TextStyle(
                      color: _textStrong,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '新規マンション追加から最初の物件を登録してください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._apartments.map((apartment) => _buildApartmentCard(context, apartment)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class ManagerAccountScreen extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const ManagerAccountScreen({
    super.key,
    required this.firestore,
    required this.auth,
    required FirebaseFunctions functions,
  });

  @override
  State<ManagerAccountScreen> createState() => _ManagerAccountScreenState();
}

class _ManagerAccountScreenState extends State<ManagerAccountScreen> {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

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
      final currentUser = widget.auth.currentUser;
      if (currentUser == null) throw Exception('ログイン情報が取得できません');

      final companyAdminId = currentUser.uid;
      final apartmentQuery = await widget.firestore
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

      final userQuery = await widget.firestore
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
                    await _fetchBuildingAdmins();
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

  Widget _buildManagerCard(
    BuildContext context,
    Map<String, dynamic> manager,
  ) {
    final apartmentName = _apartmentNames[manager['apartment']] ?? '名称不明';
    final name = manager['name']?.toString().trim();
    final email = manager['email']?.toString().trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showManagerDetailDialog(context, manager),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.supervisor_account_rounded,
                      color: _primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null || name.isEmpty ? '名前未設定' : name,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (email != null && email.isNotEmpty)
                          Text(
                            email,
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7FA),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            apartmentName,
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE7F5FB),
                  Colors.white,
                  Color(0xFFF4FBFE),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final infoColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x14004D64),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'BUILDING ADMIN ACCOUNTS',
                        style: TextStyle(
                          color: _primary,
                          fontSize: 12,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '管理人アカウントを\n一覧管理できます。',
                      style: TextStyle(
                        color: _textStrong,
                        fontSize: 34,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '担当マンションに紐づく管理人アカウントの確認、作成、削除をこの画面から行えます。',
                      style: TextStyle(
                        color: Color(0xFF5A6973),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.tonalIcon(
                      onPressed: () => _showCreateManagerDialog(context),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      label: const Text('新規アカウント作成'),
                      style: FilledButton.styleFrom(
                        foregroundColor: _primary,
                        backgroundColor: const Color(0xFFD9EDF7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ],
                );

                final summaryPanel = Container(
                  width: compact ? double.infinity : 280,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0x140C5D78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '運用サマリー',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildSummaryRow(
                        label: '管理人数',
                        value: '${_managers.length}件',
                      ),
                      const SizedBox(height: 14),
                      _buildSummaryRow(
                        label: '担当棟数',
                        value: '${_apartmentNames.length}件',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'カードをクリックすると詳細ダイアログを開き、削除操作も行えます。',
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoColumn,
                      const SizedBox(height: 22),
                      summaryPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoColumn),
                    const SizedBox(width: 24),
                    summaryPanel,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_managers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 40,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 52,
                    color: _primary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '管理しているマンションの管理人が見つかりません',
                    style: TextStyle(
                      color: _textStrong,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    '新規アカウント作成から管理人を追加してください。',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            )
          else
            ..._managers.map((manager) => _buildManagerCard(context, manager)),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompanyProfileHeroBadge extends StatelessWidget {
  const _CompanyProfileHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x14004D64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'ACCOUNT SETTINGS',
        style: TextStyle(
          color: ProfileScreen._primary,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  final FirebaseAuth auth;

  const ProfileScreen({Key? key, required this.auth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインが必要です'));
    }

    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE7F5FB),
                  Colors.white,
                  Color(0xFFF4FBFE),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final infoColumn = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CompanyProfileHeroBadge(),
                    SizedBox(height: 18),
                    Text(
                      'アカウント設定を\n安全に管理できます。',
                      style: TextStyle(
                        color: _textStrong,
                        fontSize: 34,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'ログイン中の管理会社アカウント情報を確認し、メールアドレスやパスワードの変更をこの画面から実行できます。',
                      style: TextStyle(
                        color: Color(0xFF5A6973),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                );

                final accountPanel = Container(
                  width: compact ? double.infinity : 320,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0x140C5D78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '現在のアカウント',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alternate_email_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                user.email ?? 'メール未設定',
                                style: const TextStyle(
                                  color: _textStrong,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoColumn,
                      const SizedBox(height: 22),
                      accountPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoColumn),
                    const SizedBox(width: 24),
                    accountPanel,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'セキュリティ設定',
                  style: TextStyle(
                    color: _textStrong,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '認証情報の変更は再認証を伴います。安全な環境で操作してください。',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                _buildProfileActionCard(
                  icon: Icons.edit_rounded,
                  title: 'メールアドレスを変更',
                  subtitle: 'ログインに使用するメールアドレスを更新します。',
                  onTap: () => _changeEmail(context, user),
                ),
                const SizedBox(height: 16),
                _buildProfileActionCard(
                  icon: Icons.lock_rounded,
                  title: 'パスワードを変更',
                  subtitle: '管理会社アカウントのパスワードを再設定します。',
                  onTap: () => _changePassword(context, user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: Icon(icon, color: _primary, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeEmail(BuildContext context, User user) async {
    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

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
          email: user.email!, password: pwdCtl.text.trim());
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

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

  Future<void> _changePassword(BuildContext context, User user) async {
    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

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
          email: user.email!, password: pwdCtl.text.trim());
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

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
