import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
              },
            ),

            // セクションカード：要申請の項目
            _buildSectionCard(
              title: '要申請の項目',
              onTap: () {
                // 要申請ページへ遷移
              },
            ),

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
class CurrentReservationsPage extends StatelessWidget {
  const CurrentReservationsPage({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> _getReservations() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    // 今日の 0:00 を表す DateTime
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);

    // Firestore 用 Timestamp
    final todayTimestamp = Timestamp.fromDate(todayMidnight);

    // 「userId == user.uid」かつ「date >= 今日の 0:00」だけ取得
    final reservationsSnapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: user.uid)
        .where('date', isGreaterThanOrEqualTo: todayTimestamp)
        .get();

    List<Map<String, dynamic>> reservations = [];

    for (final reservationDoc in reservationsSnapshot.docs) {
      final data = reservationDoc.data();
      final facilityId = data['facilityId'];

      // 施設情報を取得
      final facilitySnapshot = await FirebaseFirestore.instance
          .collection('facilities')
          .doc(facilityId)
          .get();

      if (facilitySnapshot.exists) {
        final facilityData = facilitySnapshot.data();

        reservations.add({
          'id': reservationDoc.id,
          'facilityName': facilityData?['name'] ?? '不明な施設',
          'imageUrl': facilityData?['image'],
          // times は [ '09:00', '09:30', ... ] のように昇順に並んでいる想定
          'startTime': data['times']?.first,
          'endTime': data['times']?.last,
          'date': data['date'], // Timestamp
        });
      }
    }

    // ▼ ここで「日付 → 開始時刻」の順でソートする
    reservations.sort((a, b) {
      final aDateTime = (a['date'] as Timestamp).toDate();
      final bDateTime = (b['date'] as Timestamp).toDate();
      // 1) 日付を比較
      final dateCompare = aDateTime.compareTo(bDateTime);
      if (dateCompare != 0) {
        return dateCompare;
      }

      // 2) 同じ日付の場合は startTime (文字列 "HH:mm") を比較
      final aStart = a['startTime'] as String;
      final bStart = b['startTime'] as String;
      return aStart.compareTo(bStart);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('現在の予約内容'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _getReservations(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              snapshot.data == null ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text('予約がありません。'));
          }

          final reservations = snapshot.data!;

          return ListView.builder(
            itemCount: reservations.length,
            itemBuilder: (context, index) {
              final reservation = reservations[index];
              final timestamp = reservation['date'] as Timestamp;
              final reservation_date = timestamp.toDate();
              final year = reservation_date.year;
              final month = reservation_date.month.toString().padLeft(2, '0');
              final day = reservation_date.day.toString().padLeft(2, '0');

              final formattedDate = '$year/$month/$day';

              return GestureDetector(
                onTap: () {
                  _showCancelDialog(
                    context,
                    reservation['id'],
                    reservation['facilityName'],
                  );
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 16.0,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        reservation['imageUrl'] != null
                            ? Image.network(
                                reservation['imageUrl'],
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image, size: 80),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reservation['facilityName'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '$formattedDate\n'
                                '${reservation['startTime']} - ${reservation['endTime']}',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
