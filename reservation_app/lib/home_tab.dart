// ✅ 完全版: Firebase依存注入対応 HomeTab & CurrentReservationsPage
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:reservation_app/pdf_view_screen.dart';

class HomeTab extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const HomeTab({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ?? FirebaseFunctions.instance,
        super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
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
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.auth.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
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
            _buildSectionCard(
              title: '新しい掲示',
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
                }),
            _buildSectionCard(
                title: 'プロフィール修正', onTap: () => _showProfileDialog(context)),
            _buildSectionCard(
                title: 'メールアドレスをリセット', onTap: () => _resetEmail(context)),
            _buildSectionCard(
                title: 'パスワードをリセット', onTap: () => _resetPassword(context)),
            _buildSectionCard(
                title: '家族アカウント作成', onTap: () => _showAddFamilyDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
      {required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          title: Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          trailing: const Icon(Icons.arrow_forward_ios),
        ),
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
