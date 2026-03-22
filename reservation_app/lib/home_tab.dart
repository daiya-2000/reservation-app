// ✅ 完全版: Firebase依存注入対応 HomeTab & CurrentReservationsPage
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:reservation_app/pdf_view_screen.dart';

class HomeTab extends StatefulWidget {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;
  final FirebaseFunctions? _functions;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get functions => _functions ?? FirebaseFunctions.instance;

  const HomeTab({
    super.key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth,
        _firestore = firestore,
        _functions = functions;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  static const _background = Color(0xFFF7F9FB);
  static const _primary = Color(0xFF004D64);
  static const _textMuted = Color(0xFF5E6C76);

  User? _currentUser;
  Map<String, dynamic>? _userInfo;
  String? _apartmentName;
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();

    _authSubscription = widget.auth.authStateChanges().listen((user) {
      if (user != null) {
        setState(() => _currentUser = user);
        _fetchUserData();
      }
    });

    _currentUser = widget.auth.currentUser;
    _fetchUserData();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await widget.firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null && mounted) {
        setState(() => _userInfo = userData);
      }

      final apartmentId = userData?['apartment'];
      if (apartmentId != null) {
        final apartmentDoc = await widget.firestore
            .collection('apartments')
            .doc(apartmentId)
            .get();
        if (mounted) {
          setState(() =>
              _apartmentName = apartmentDoc.data()?['name'] ?? '不明なマンション');
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  // --- プロフィール修正ダイアログ ---
  Future<void> _showProfileDialog(BuildContext context) async {
    final controller = TextEditingController(text: _userInfo?['name'] ?? '');

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('プロフィール修正'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: _apartmentName ?? '不明'),
              readOnly: true,
              decoration: const InputDecoration(labelText: 'マンション名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller:
                  TextEditingController(text: _userInfo?['roomNumber'] ?? ''),
              readOnly: true,
              decoration: const InputDecoration(labelText: '部屋番号'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: '氏名'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              try {
                await widget.firestore
                    .collection('users')
                    .doc(_currentUser!.uid)
                    .update({
                  'name': controller.text.trim(),
                });
                await _fetchUserData();
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('プロフィールが更新されました。')));
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

  // --- メールアドレスリセット ---
  Future<void> _resetEmail(BuildContext context) async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newEmailController = TextEditingController();
    final TextEditingController confirmEmailController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('メールアドレスリセット'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('現在のパスワードを入力してください。'),
              const SizedBox(height: 8),
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '現在のパスワード',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final credential = EmailAuthProvider.credential(
                    email: _currentUser?.email ?? '',
                    password: currentPasswordController.text.trim(),
                  );
                  await _currentUser?.reauthenticateWithCredential(credential);
                  Navigator.pop(context);

                  // 新しいメールアドレス入力ダイアログ
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('新しいメールアドレスを入力'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('新しいメールアドレスを入力してください。'),
                            TextField(
                              controller: newEmailController,
                              decoration: const InputDecoration(
                                labelText: '新しいメールアドレス',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmEmailController,
                              decoration: const InputDecoration(
                                labelText: '新しいメールアドレス（確認用）',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('キャンセル'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (newEmailController.text.trim() !=
                                  confirmEmailController.text.trim()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('メールアドレスが一致しません。')),
                                );
                                return;
                              }
                              try {
                                await _currentUser?.verifyBeforeUpdateEmail(
                                    newEmailController.text.trim());
                                await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(_currentUser?.uid)
                                    .update({
                                  'email': newEmailController.text.trim(),
                                });
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '確認メールを新しいアドレスに送信しました。確認後に変更が有効になります。',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('エラー: $e')),
                                );
                              }
                            },
                            child: const Text('保存'),
                          ),
                        ],
                      );
                    },
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('エラー: $e')));
                }
              },
              child: const Text('次へ'),
            ),
          ],
        );
      },
    );
  }

  // --- パスワードリセット ---
  Future<void> _resetPassword(BuildContext context) async {
    final currentEmail = _currentUser?.email ?? '';
    final newPasswordController = TextEditingController();
    final confirmController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('パスワードを変更'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '新しいパスワード'),
            ),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '確認用パスワード'),
            ),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: '現在のパスワード'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              final newPass = newPasswordController.text.trim();
              final confirmPass = confirmController.text.trim();
              final currentPass = passwordController.text.trim();

              if (newPass != confirmPass) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードが一致しません')));
                return;
              }

              try {
                final cred = EmailAuthProvider.credential(
                    email: currentEmail, password: currentPass);
                await _currentUser!.reauthenticateWithCredential(cred);
                await _currentUser!.updatePassword(newPass);
                if (mounted) Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードを変更しました')));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('エラー: $e')));
              }
            },
            child: const Text('変更'),
          ),
        ],
      ),
    );
  }

  // --- 家族アカウント作成 ---
  Future<void> _showAddFamilyDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('家族アカウント作成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '氏名')),
            TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス')),
            TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'パスワード')),
            TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認用パスワード')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              final pass = passwordController.text.trim();
              final confirm = confirmController.text.trim();

              if (pass != confirm) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードが一致しません')));
                return;
              }

              try {
                final userData = {
                  'name': name,
                  'email': email,
                  'password': pass,
                  'role': _userInfo?['role'],
                  'roomNumber': _userInfo?['roomNumber'],
                  'apartment': _userInfo?['apartment'],
                };

                final result = await widget.functions
                    .httpsCallable('createFamilyAccount')
                    .call(userData);
                if (result.data['success'] == true) {
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('アカウントを作成しました')));
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('作成に失敗しました')));
                }
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('エラー: $e')));
              }
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userInfo == null || _apartmentName == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _buildHeader(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: _buildProfileHero(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: _buildSectionTitle(
                  '最新情報の確認',
                  'よく使う情報へすぐに移動できます。',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionCard(
                    title: '新しい掲示',
                    subtitle: '直近1ヶ月のお知らせをまとめて確認',
                    icon: Icons.forum_outlined,
                    accentColor: const Color(0xFFE8F7FF),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RecentBulletinPage(
                            firestore: widget.firestore,
                          ),
                        ),
                      );
                    },
                  ),
                  _buildSectionCard(
                    title: '現在の予約内容',
                    subtitle: '自分と家族の予約状況を一覧表示',
                    icon: Icons.event_available_rounded,
                    accentColor: const Color(0xFFEFF7EA),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CurrentReservationsPage(
                            auth: widget.auth,
                            firestore: widget.firestore,
                          ),
                        ),
                      );
                    },
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: _buildSectionTitle(
                  'アカウント設定',
                  'プロフィールや認証情報、家族アカウントを管理します。',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSectionCard(
                    title: 'プロフィール修正',
                    subtitle: '氏名など基本情報を更新',
                    icon: Icons.edit_outlined,
                    accentColor: const Color(0xFFFFF3EA),
                    onTap: () => _showProfileDialog(context),
                  ),
                  _buildSectionCard(
                    title: 'メールアドレスをリセット',
                    subtitle: '確認メールで新しいアドレスへ変更',
                    icon: Icons.alternate_email_rounded,
                    accentColor: const Color(0xFFF2EEFF),
                    onTap: () => _resetEmail(context),
                  ),
                  _buildSectionCard(
                    title: 'パスワードをリセット',
                    subtitle: '現在の認証情報を確認して更新',
                    icon: Icons.lock_reset_rounded,
                    accentColor: const Color(0xFFEAF4FF),
                    onTap: () => _resetPassword(context),
                  ),
                  _buildSectionCard(
                    title: '家族アカウント作成',
                    subtitle: '同じ部屋番号の家族アカウントを追加',
                    icon: Icons.group_add_outlined,
                    accentColor: const Color(0xFFEFF7EA),
                    onTap: () => _showAddFamilyDialog(context),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'マイページ',
                style: TextStyle(
                  color: _primary,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'プロフィール、予約状況、各種設定をまとめて管理できます。',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              await widget.auth.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(Icons.logout_rounded, color: _primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHero() {
    final roomNumber = _userInfo?['roomNumber']?.toString() ?? '不明';
    final userName = _userInfo?['name']?.toString() ?? '不明';
    final email = _currentUser?.email ?? _userInfo?['email']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14004D64),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName.characters.first : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Color(0xFF182227),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email.isNotEmpty ? email : 'メールアドレス未設定',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: Icons.apartment_rounded,
                label: _apartmentName ?? '不明なマンション',
              ),
              _InfoChip(
                icon: Icons.meeting_room_outlined,
                label: '部屋番号 $roomNumber',
                secondary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF172126),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: _primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF182227),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF42525C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool secondary;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: secondary ? const Color(0xFFF3F6F8) : const Color(0xFFD8ECF7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF33515F)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF33515F),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class RecentBulletinPage extends StatefulWidget {
  final FirebaseFirestore firestore;

  const RecentBulletinPage({Key? key, required this.firestore})
      : super(key: key);

  @override
  State<RecentBulletinPage> createState() => _RecentBulletinPageState();
}

class _RecentBulletinPageState extends State<RecentBulletinPage> {
  List<Map<String, dynamic>> _recentPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRecentPosts();
  }

  Future<void> _fetchRecentPosts() async {
    try {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));

      final snapshot = await widget.firestore
          .collection('bulletin_posts')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(oneMonthAgo))
          .orderBy('createdAt', descending: true)
          .get();

      final posts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'title': data['title'] ?? '無題',
          'body': data['body'] ?? '',
          'pdfUrl': data['pdfUrl'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _recentPosts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('掲示取得失敗: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('掲示の取得に失敗しました')),
        );
      }
    }
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post['title']),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['body']),
                const SizedBox(height: 16),
                if (post['pdfUrl'] != null)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(url: post['pdfUrl']),
                        ),
                      );
                    },
                    child: const Text('PDFを表示'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate =
        date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '不明';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        title: Text(post['title']),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post['body'], maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('投稿日: $formattedDate',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPostDetailDialog(post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新しい掲示')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recentPosts.isEmpty
              ? const Center(child: Text('1ヶ月以内に投稿された掲示板はありません。'))
              : ListView.builder(
                  itemCount: _recentPosts.length,
                  itemBuilder: (context, index) =>
                      _buildPostCard(_recentPosts[index]),
                ),
    );
  }
}

class CurrentReservationsPage extends StatefulWidget {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const CurrentReservationsPage(
      {Key? key, required this.firestore, required this.auth})
      : super(key: key);

  @override
  State<CurrentReservationsPage> createState() =>
      _CurrentReservationsPageState();
}

class _CurrentReservationsPageState extends State<CurrentReservationsPage> {
  late User user;
  late Future<List<Map<String, dynamic>>> reservationsFuture;

  @override
  void initState() {
    super.initState();
    user = widget.auth.currentUser!;
    reservationsFuture = _getReservations(user);
  }

  Future<void> _refreshReservations() async {
    setState(() {
      reservationsFuture = _getReservations(user);
    });
  }

  Future<List<Map<String, dynamic>>> _getReservations(User user) async {
    final userDoc =
        await widget.firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData == null) return [];

    final apartment = userData['apartment'];
    final roomNumber = userData['roomNumber'];
    if (apartment == null || roomNumber == null) return [];

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todayTimestamp = Timestamp.fromDate(todayMidnight);

    final familyUsers = await widget.firestore
        .collection('users')
        .where('apartment', isEqualTo: apartment)
        .where('roomNumber', isEqualTo: roomNumber)
        .get();

    final familyUserIds = familyUsers.docs.map((doc) => doc.id).toList();
    final userMap = {
      for (var doc in familyUsers.docs) doc.id: doc.data()['name']
    };

    final reservationsSnapshot = await widget.firestore
        .collection('reservations')
        .where('userId', whereIn: familyUserIds)
        .where('date', isGreaterThanOrEqualTo: todayTimestamp)
        .get();

    List<Map<String, dynamic>> reservations = [];

    for (final doc in reservationsSnapshot.docs) {
      final data = doc.data();
      final facilityId = data['facilityId'];
      final reservationUserId = data['userId'];

      final facilitySnapshot =
          await widget.firestore.collection('facilities').doc(facilityId).get();

      if (facilitySnapshot.exists) {
        final facilityData = facilitySnapshot.data();

        reservations.add({
          'id': doc.id,
          'userId': reservationUserId,
          'userName': userMap[reservationUserId] ?? '不明なユーザー',
          'facilityName': facilityData?['name'] ?? '不明な施設',
          'imageUrl': facilityData?['image'],
          'startTime': data['times']?.first,
          'endTime': data['times']?.last,
          'date': data['date'],
        });
      }
    }

    reservations.sort((a, b) {
      final aDateTime = (a['date'] as Timestamp).toDate();
      final bDateTime = (b['date'] as Timestamp).toDate();
      final dateCompare = aDateTime.compareTo(bDateTime);
      if (dateCompare != 0) return dateCompare;
      return (a['startTime'] as String).compareTo(b['startTime'] as String);
    });

    return reservations;
  }

  Future<void> _cancelReservation(String reservationId) async {
    await widget.firestore
        .collection('reservations')
        .doc(reservationId)
        .delete();
  }

  void _showCancelDialog(
      BuildContext context, String reservationId, String facilityName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('予約をキャンセルしますか？'),
        content: Text('施設名: $facilityName'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('戻る')),
          ElevatedButton(
            onPressed: () async {
              await _cancelReservation(reservationId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('予約をキャンセルしました。')),
              );
              await _refreshReservations();
            },
            child: const Text('キャンセルする'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('現在の予約内容')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: reservationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('予約がありません。'));
          }

          final reservations = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshReservations,
            child: ListView.builder(
              itemCount: reservations.length,
              itemBuilder: (context, index) {
                final r = reservations[index];
                final date = (r['date'] as Timestamp).toDate();
                final formatted =
                    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
                return Card(
                  margin:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: ListTile(
                    leading: r['imageUrl'] != null
                        ? Image.network(r['imageUrl'],
                            width: 80, height: 80, fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 80),
                    title: Text(r['facilityName'],
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (r['userId'] != user.uid)
                          Text('予約者: ${r['userName']}'),
                        Text('$formatted\n${r['startTime']} - ${r['endTime']}'),
                      ],
                    ),
                    trailing: r['userId'] == user.uid
                        ? IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () => _showCancelDialog(
                                context, r['id'], r['facilityName']),
                          )
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
