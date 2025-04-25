import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:reservation_app/bulletin_tab.dart';
import 'package:reservation_app/pdf_view_screen.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  User? _currentUser;
  Map<String, dynamic>? _userInfo;
  String? _apartmentName;
  late StreamSubscription<User?> _authSubscription;

  List<Map<String, dynamic>> _latestPosts = [];

  @override
  void initState() {
    super.initState();

    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        _fetchUserData();
      }
    });

    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserData();
    _fetchLatestPosts();
  }

  @override
  void dispose() {
    _authSubscription.cancel(); // リスナーをキャンセル
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null && mounted) {
        setState(() {
          _userInfo = userData;
        });
      }

      final apartmentId = userData?['apartment'];
      if (apartmentId != null) {
        final apartmentDoc = await FirebaseFirestore.instance
            .collection('apartments')
            .doc(apartmentId)
            .get();
        if (mounted) {
          setState(() {
            _apartmentName = apartmentDoc.data()?['name'] ?? '不明なマンション';
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
    }
  }

  Future<void> _fetchLatestPosts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bulletin_posts')
          .orderBy('createdAt', descending: true)
          .limit(5)
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
          _latestPosts = posts;
        });
      }
    } catch (e) {
      debugPrint('掲示の取得に失敗しました: $e');
    }
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post['title']),
        content: SingleChildScrollView(
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
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestPostCard(Map<String, dynamic> post) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate =
        date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '不明';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(post['title']),
        subtitle: Text('投稿日: $formattedDate'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPostDetailDialog(post),
      ),
    );
  }

  // プロフィール修正ダイアログ
  Future<void> _showProfileDialog(
    BuildContext context,
    Map<String, dynamic> userInfo,
    String apartmentName,
  ) async {
    final TextEditingController nameController =
        TextEditingController(text: userInfo['name']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('プロフィール修正'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // マンション名 (固定表示)
                TextField(
                  controller: TextEditingController(text: apartmentName),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'マンション名(固定)'),
                ),
                const SizedBox(height: 8),
                // 部屋番号 (固定表示)
                TextField(
                  controller:
                      TextEditingController(text: userInfo['roomNumber']),
                  readOnly: true,
                  decoration: const InputDecoration(labelText: '部屋番号(固定)'),
                ),
                const SizedBox(height: 8),
                // 名前 (修正可能)
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名前'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Firestore データ更新
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(_currentUser?.uid)
                      .update({
                    'name': nameController.text.trim(),
                  });

                  await _fetchUserData(); // 最新データを取得
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('プロフィールが更新されました。')),
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
  }

  // メールアドレスリセット
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

  // パスワードリセット
  Future<void> _resetPassword(BuildContext context) async {
    final TextEditingController currentPasswordController =
        TextEditingController();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('パスワードリセット'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('現在のパスワードを入力してください。'),
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
                child: const Text('キャンセル')),
            ElevatedButton(
              onPressed: () async {
                try {
                  final credential = EmailAuthProvider.credential(
                    email: _currentUser?.email ?? '',
                    password: currentPasswordController.text.trim(),
                  );
                  await _currentUser?.reauthenticateWithCredential(credential);
                  Navigator.pop(context);

                  // 新しいパスワード入力ダイアログ
                  await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('新しいパスワードを入力'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('新しいパスワードを入力してください。'),
                            TextField(
                              controller: newPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '新しいパスワード',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: confirmPasswordController,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '新しいパスワード（確認用）',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('キャンセル')),
                          ElevatedButton(
                            onPressed: () async {
                              if (newPasswordController.text.trim() !=
                                  confirmPasswordController.text.trim()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('パスワードが一致しません。')),
                                );
                                return;
                              }
                              try {
                                await _currentUser?.updatePassword(
                                    newPasswordController.text.trim());
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('パスワードが更新されました。')),
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

  Future<void> createFamilyAccount({
    required String name,
    required String email,
    required String password,
  }) async {
    final callable =
        FirebaseFunctions.instance.httpsCallable('createFamilyAccount');

    try {
      final result = await callable.call({
        'name': name,
        'email': email,
        'password': password,
      });

      if (result.data['success'] == true) {
        debugPrint('✅ 家族アカウントを作成しました');
      } else {
        debugPrint('⚠️ 作成は失敗しました');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('❌ Cloud Functions エラー: ${e.message}');
      rethrow;
    }
  }

  Future<void> _showAddFamilyDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final confirmEmailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('家族アカウント作成'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '氏名'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'メールアドレス'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmEmailController,
                  decoration: const InputDecoration(labelText: 'メールアドレス（確認用）'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'パスワード（確認用）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final confirmEmail = confirmEmailController.text.trim();
                final password = passwordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (name.isEmpty ||
                    email.isEmpty ||
                    confirmEmail.isEmpty ||
                    password.isEmpty ||
                    confirmPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('すべての項目を入力してください')),
                  );
                  return;
                }

                if (email != confirmEmail) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('メールアドレスが一致しません')),
                  );
                  return;
                }

                if (password != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードが一致しません')),
                  );
                  return;
                }

                // 🔒 認証済みかチェック
                if (_currentUser == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ログインしてからご利用ください')),
                  );
                  return;
                }

                try {
                  final callable = FirebaseFunctions.instance
                      .httpsCallable('createFamilyAccount');
                  final Map<String, dynamic> data = {
                    'name': name,
                    'email': email,
                    'password': password,
                    'role': _userInfo?['role'],
                    'roomNumber': _userInfo?['roomNumber'],
                    'apartment': _userInfo?['apartment'],
                  };

                  data.removeWhere((key, value) => value == null); // null除外

                  final result = await callable.call(data);

                  Navigator.pop(context);

                  if (result.data['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('家族アカウントを作成しました')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'アカウント作成に失敗しました: ${result.data['error'] ?? '不明なエラー'}')),
                    );
                  }
                } on FirebaseFunctionsException catch (e) {
                  Navigator.pop(context);
                  debugPrint('❌ Cloud Functions エラー: ${e.message}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('エラー: ${e.message}')),
                  );
                } catch (e) {
                  Navigator.pop(context);
                  debugPrint('❌ その他のエラー: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('予期せぬエラーが発生しました: $e')),
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
    // ユーザー情報やマンション名がまだ読み込まれていない場合はローディング
    if (_userInfo == null || _apartmentName == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('マンション名: $_apartmentName',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('部屋番号: ${_userInfo?['roomNumber'] ?? '不明'}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('氏名: ${_userInfo?['name'] ?? '不明'}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),

            // セクションカード：新しい掲示
            _buildSectionCard(
              title: '新しい掲示',
              onTap: () {
                // 新しい掲示ページへ遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const BulletinTab(),
                  ),
                );
              },
            ),

            // セクションカード：要申請の項目
            // _buildSectionCard(
            //   title: '要申請の項目',
            //   onTap: () {
            //     // 要申請ページへ遷移
            //   },
            // ),

            // セクションカード：現在の予約内容
            _buildSectionCard(
              title: '現在の予約内容',
              onTap: () {
                // 現在の予約内容ページ (CurrentReservationsPage) へ遷移
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CurrentReservationsPage(),
                  ),
                );
              },
            ),

            // プロフィール修正
            _buildSectionCard(
              title: 'プロフィール修正',
              onTap: () {
                _showProfileDialog(context, _userInfo!, _apartmentName!);
              },
            ),

            // メールアドレスをリセット
            _buildSectionCard(
              title: 'メールアドレスをリセット',
              onTap: () {
                _resetEmail(context);
              },
            ),

            // パスワードをリセット
            _buildSectionCard(
              title: 'パスワードをリセット',
              onTap: () {
                _resetPassword(context);
              },
            ),
            // 家族アカウント作成
            _buildSectionCard(
              title: '家族アカウント作成',
              onTap: () => _showAddFamilyDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          title: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
        ),
      ),
    );
  }
}

/// 現在の予約内容ページ
class CurrentReservationsPage extends StatefulWidget {
  const CurrentReservationsPage({Key? key}) : super(key: key);

  @override
  State<CurrentReservationsPage> createState() =>
      _CurrentReservationsPageState();
}

class _CurrentReservationsPageState extends State<CurrentReservationsPage> {
  User? user;
  late Future<List<Map<String, dynamic>>> reservationsFuture;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    reservationsFuture = _getReservations(user!);
  }

  Future<void> _refreshReservations() async {
    setState(() {
      reservationsFuture = _getReservations(user!);
    });
  }

  Future<List<Map<String, dynamic>>> _getReservations(User user) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data();
    if (userData == null) return [];

    final apartment = userData['apartment'];
    final roomNumber = userData['roomNumber'];
    if (apartment == null || roomNumber == null) return [];

    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final todayTimestamp = Timestamp.fromDate(todayMidnight);

    final familyUsers = await FirebaseFirestore.instance
        .collection('users')
        .where('apartment', isEqualTo: apartment)
        .where('roomNumber', isEqualTo: roomNumber)
        .get();

    final familyUserIds = familyUsers.docs.map((doc) => doc.id).toList();
    final userMap = {
      for (var doc in familyUsers.docs) doc.id: doc.data()['name']
    };

    final reservationsSnapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', whereIn: familyUserIds)
        .where('date', isGreaterThanOrEqualTo: todayTimestamp)
        .get();

    List<Map<String, dynamic>> reservations = [];

    for (final doc in reservationsSnapshot.docs) {
      final data = doc.data();
      final facilityId = data['facilityId'];
      final reservationUserId = data['userId'];

      final facilitySnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .get();

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
    await FirebaseFirestore.instance
        .collection('reservations')
        .doc(reservationId)
        .delete();
  }

  void _showCancelDialog(
      BuildContext context, String reservationId, String facilityName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('予約をキャンセルしますか？'),
          content: Text('施設名: $facilityName'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('戻る'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _cancelReservation(reservationId);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('予約をキャンセルしました。')),
                );
                await _refreshReservations(); // 即時反映
              },
              child: const Text('キャンセルする'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('ログインが必要です'));
    }

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
                final reservation = reservations[index];
                final reservationDate =
                    (reservation['date'] as Timestamp).toDate();
                final formattedDate =
                    '${reservationDate.year}/${reservationDate.month.toString().padLeft(2, '0')}/${reservationDate.day.toString().padLeft(2, '0')}';

                return Card(
                  margin: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
                  child: ListTile(
                    leading: reservation['imageUrl'] != null
                        ? Image.network(
                            reservation['imageUrl'],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          )
                        : const Icon(Icons.image, size: 80),
                    title: Text(
                      reservation['facilityName'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reservation['userId'] != user!.uid)
                          Text('予約者: ${reservation['userName']}'),
                        Text(
                            '$formattedDate\n${reservation['startTime']} - ${reservation['endTime']}'),
                      ],
                    ),
                    trailing: reservation['userId'] == user!.uid
                        ? IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: () {
                              _showCancelDialog(context, reservation['id'],
                                  reservation['facilityName']);
                            },
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
