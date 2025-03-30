import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// 画像選択 + Firebase Storage
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// kIsWeb 判定
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File; // モバイルで使う
import 'dart:typed_data'; // Webで使う Uint8List

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({Key? key}) : super(key: key);

  @override
  _OperatorScreenState createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    HomeScreen(),
    const FacilityCalendarScreen(),
    const PlaceholderScreen(title: '掲示板'),
    const PlaceholderScreen(title: '申請・アンケート'),
    const AccountScreen(),
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
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home),
                label: Text(
                  'ホーム',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text(
                  '施設カレンダー',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message),
                label: Text(
                  '掲示板',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.note),
                label: Text(
                  '申請・アンケート',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_circle),
                label: Text(
                  'アカウント',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------------
   ホーム画面
---------------------------------------------------------------- */
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
                  side: const BorderSide(color: Colors.purple),
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

/* ----------------------------------------------------------------
   施設カレンダー画面 (メイン)
---------------------------------------------------------------- */
class FacilityCalendarScreen extends StatefulWidget {
  const FacilityCalendarScreen({Key? key}) : super(key: key);

  @override
  _FacilityCalendarScreenState createState() => _FacilityCalendarScreenState();
}

class _FacilityCalendarScreenState extends State<FacilityCalendarScreen> {
  List<Map<String, dynamic>> _facilities = [];
  String? _selectedFacilityId;

  DateTime _selectedMonth = DateTime.now();
  Map<int, List<Map<String, String>>> _reservationsByDay = {};

  bool _isLoading = false;

  // image_picker 用
  final ImagePicker _picker = ImagePicker();

  // Webの場合はバイトデータ(Uint8List)
  Uint8List? _webImage;
  // モバイルの場合はXFile
  XFile? _mobileImageFile;

  @override
  void initState() {
    super.initState();
    _fetchFacilities();
  }

  // 施設一覧を取得
  Future<void> _fetchFacilities() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('facilities').get();

    final facilityList =
        snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();

    setState(() {
      _facilities = facilityList;
      if (_facilities.isNotEmpty) {
        _selectedFacilityId = facilityList.first['id'];
      }
    });

    if (_selectedFacilityId != null) {
      await _fetchReservationsForMonth();
    }
  }

  // 選択施設 & 選択月 の予約を取得
  Future<void> _fetchReservationsForMonth() async {
    if (_selectedFacilityId == null) return;

    setState(() {
      _isLoading = true;
      _reservationsByDay.clear();
    });

    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)
        .subtract(const Duration(seconds: 1));

    final fromTs = Timestamp.fromDate(firstDay);
    final toTs = Timestamp.fromDate(lastDay);

    final querySnapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('facilityId', isEqualTo: _selectedFacilityId)
        .where('date', isGreaterThanOrEqualTo: fromTs)
        .where('date', isLessThanOrEqualTo: toTs)
        .get();

    final Map<int, List<Map<String, String>>> dayMap = {};

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final ts = data['date'] as Timestamp;
      final dt = ts.toDate();
      final day = dt.day;

      final times = List<String>.from(data['times'] ?? []);
      times.sort();
      if (times.isEmpty) continue;

      final start = times.first;
      final end = times.last;
      final interval = '$start ~ $end';

      // 予約ユーザー情報
      final userId = data['userId'] ?? '';
      String roomNumber = '不明';
      String userName = '不明';

      if (userId.isNotEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          roomNumber = userData['roomNumber']?.toString() ?? '不明';
          userName = userData['name']?.toString() ?? '不明';
        }
      }

      final reservationInfo = {
        'interval': interval,
        'roomNumber': roomNumber,
        'userName': userName,
      };

      dayMap[day] = (dayMap[day] ?? [])..add(reservationInfo);
    }

    // 時刻順にソート
    dayMap.forEach((day, list) {
      list.sort((a, b) => a["interval"]!.compareTo(b["interval"]!));
    });

    setState(() {
      _reservationsByDay = dayMap;
      _isLoading = false;
    });
  }

  // 前月へ
  void _previousMonth() async {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    });
    await _fetchReservationsForMonth();
  }

  // 翌月へ
  void _nextMonth() async {
    setState(() {
      _selectedMonth =
          DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1);
    });
    await _fetchReservationsForMonth();
  }

  // 施設変更
  void _onFacilityChanged(String? newFacilityId) async {
    setState(() {
      _selectedFacilityId = newFacilityId;
    });
    await _fetchReservationsForMonth();
  }

  // ★ 新規施設追加ボタン押下時のハンドラ
  // ★ 新規施設追加ボタン押下
  void _addNewFacility() {
    _showAddFacilityDialog();
  }

  // カレンダー編集
  void _editCalendar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('カレンダー編集ボタンが押されました')),
    );
  }

  // 予定のエクスポート
  void _exportSchedule() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('予定のエクスポートボタンが押されました')),
    );
  }

  // 日付セルタップ -> その日の予約をダイアログ表示
  void _showDayReservationsDialog(int day) {
    final reservations = _reservationsByDay[day] ?? [];
    final year = _selectedMonth.year;
    final month = _selectedMonth.month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');
    final titleText = '$year年$month月$dayStr日の予約';

    if (reservations.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(titleText),
            content: const Text('予約はありません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 予約あり
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(titleText),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: reservations.map((r) {
                final interval = r['interval'] ?? '不明';
                final roomNumber = r['roomNumber'] ?? '不明';
                final userName = r['userName'] ?? '不明';

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('部屋番号: $roomNumber'),
                        const SizedBox(height: 4),
                        Text('名前: $userName'),
                        const SizedBox(height: 4),
                        Text('時間: $interval'),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1)
            .subtract(const Duration(days: 1));
    final daysInMonth = lastDayOfMonth.day;

    final firstWeekday = (firstDayOfMonth.weekday % 7); // 日=0, 月=1, ... 土=6
    final dayCells = <Widget>[];

    // 月初の空セル
    for (int i = 0; i < firstWeekday; i++) {
      dayCells.add(Container());
    }

    // 実際の日付セル
    for (int day = 1; day <= daysInMonth; day++) {
      final dayReservations = _reservationsByDay[day] ?? [];
      final displayedIntervals =
          dayReservations.take(3).map((r) => r['interval'] ?? '').toList();

      dayCells.add(
        MouseRegion(
          cursor: SystemMouseCursors.click, // ← ポインターに変化
          child: GestureDetector(
            onTap: () {
              // 日付セルをクリック → ダイアログ表示
              _showDayReservationsDialog(day);
            },
            child: Container(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$day日',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  for (int i = 0; i < displayedIntervals.length; i++)
                    Text(
                      displayedIntervals[i],
                      style: const TextStyle(fontSize: 12),
                    ),
                  if (dayReservations.length > 3)
                    const Text(
                      '...',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // 月末の空セル
    while (dayCells.length % 7 != 0) {
      dayCells.add(Container());
    }

    return Column(
      children: [
        // 曜日ラベル
        const Row(
          children: [
            Expanded(
                child: Center(
                    child: Text('日',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('月',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('火',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('水',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('木',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('金',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
            Expanded(
                child: Center(
                    child: Text('土',
                        style: TextStyle(fontWeight: FontWeight.bold)))),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 7,
            children: dayCells,
          ),
        ),
      ],
    );
  }

  // 画像アップロード付き 施設追加ダイアログ (Web/モバイル対応)
  // 画像アップロード付き 施設追加ダイアログ (Web/モバイル対応)
  void _showAddFacilityDialog() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    Uint8List? webImage;
    XFile? mobileImageFile;
    String? imageUrl;
    String? imageExtension; // 拡張子保持

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            // 画像選択
            Future<void> _pickImage() async {
              final XFile? file =
                  await _picker.pickImage(source: ImageSource.gallery);
              if (file == null) return;

              String? ext;

              if (kIsWeb) {
                // Web: 拡張子は取れないため、mimeType で判定
                final mime = file.mimeType ?? '';
                if (mime == 'image/png') {
                  ext = 'png';
                } else if (mime == 'image/jpeg') {
                  ext = 'jpg';
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JPEGまたはPNGの画像を選択してください。')),
                  );
                  return;
                }

                final bytes = await file.readAsBytes();
                setStateDialog(() {
                  webImage = bytes;
                  imageExtension = ext;
                });
              } else {
                // モバイル: path から拡張子取得
                ext = file.path.split('.').last.toLowerCase().trim();
                if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JPEGまたはPNGの画像を選択してください。')),
                  );
                  return;
                }

                setStateDialog(() {
                  mobileImageFile = file;
                  imageExtension = ext == 'jpeg' ? 'jpg' : ext;
                });
              }
            }

            // Firebase Storage にアップロード (Web/モバイル分岐)
            Future<String> _uploadImageToStorage() async {
              if (imageExtension == null) {
                throw Exception('画像の拡張子が不明です');
              }

              final fileName =
                  'facilities/${DateTime.now().millisecondsSinceEpoch}.$imageExtension';
              final ref = FirebaseStorage.instance.ref().child(fileName);

              final metadata = SettableMetadata(
                contentType:
                    imageExtension == 'png' ? 'image/png' : 'image/jpeg',
              );

              if (kIsWeb && webImage != null) {
                await ref.putData(webImage!, metadata);
              } else if (!kIsWeb && mobileImageFile != null) {
                await ref.putFile(File(mobileImageFile!.path), metadata);
              }

              return await ref.getDownloadURL();
            }

            // Firestoreに登録
            Future<void> _saveFacility() async {
              try {
                final name = nameController.text.trim();
                final priceText = priceController.text.trim();

                if (name.isEmpty || priceText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('施設名と価格を入力してください。')),
                  );
                  return;
                }

                if (!RegExp(r'^[0-9]+$').hasMatch(priceText)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('価格は半角数字で入力してください。')),
                  );
                  return;
                }

                if (imageExtension == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('画像を選択してください。')),
                  );
                  return;
                }

                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;

                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .get();
                final apartmentId = userDoc['apartment'] ?? 'unknown_apartment';

                imageUrl = await _uploadImageToStorage();

                await FirebaseFirestore.instance.collection('facilities').add({
                  'apartment_id': apartmentId,
                  'image': imageUrl,
                  'name': name,
                  'price': priceText,
                });

                Navigator.pop(context);
                _fetchFacilities(); // 再読み込み

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('施設を登録しました。')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
              }
            }

            // プレビューWidget
            Widget _buildPreview() {
              if (kIsWeb && webImage != null) {
                return Image.memory(
                  webImage!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                );
              } else if (!kIsWeb && mobileImageFile != null) {
                return Image.file(
                  File(mobileImageFile!.path),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                );
              }
              return const SizedBox.shrink();
            }

            return AlertDialog(
              title: const Text('新規施設追加'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _pickImage,
                      child: const Text('画像を選択 (JPEG/PNG)'),
                    ),
                    const SizedBox(height: 8),
                    _buildPreview(),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: '施設名'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      decoration: const InputDecoration(labelText: '価格'),
                      keyboardType: TextInputType.number,
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
                  onPressed: _saveFacility,
                  child: const Text('登録'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonStyle = ElevatedButton.styleFrom(
      fixedSize: const Size(160, 40),
    );

    final year = _selectedMonth.year;
    final month = _selectedMonth.month.toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 上部 (施設プルダウン + 新規施設追加 & カレンダー編集)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側: 施設プルダウン
              Row(
                children: [
                  const Text(
                    '施設名: ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_facilities.isEmpty)
                    const Text('読み込み中...')
                  else
                    Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).primaryColor,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: Theme.of(context).primaryColor,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                            iconEnabledColor: Colors.white,
                            value: _selectedFacilityId,
                            items: _facilities.map((facility) {
                              return DropdownMenuItem<String>(
                                value: facility['id'],
                                child: Text(facility['name'] ?? '名称不明'),
                              );
                            }).toList(),
                            onChanged: _onFacilityChanged,
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // 右側: 新規施設追加ボタン & カレンダー編集ボタン
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _addNewFacility,
                    child: const Text('新規施設追加'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _editCalendar,
                    child: const Text('カレンダー編集'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 月切り替え
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousMonth,
              ),
              Text('$year年 $month月', style: const TextStyle(fontSize: 16)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // カレンダー表示
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: _buildCalendar(),
                  ),
          ),
          const SizedBox(height: 16),

          // 予定のエクスポート
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _exportSchedule,
              child: const Text('予定のエクスポート'),
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------------
   アカウント管理画面
---------------------------------------------------------------- */
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

    final roomNumberController = TextEditingController();
    final passwordController = TextEditingController();

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
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final userCredential = await FirebaseAuth.instance
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
              onPressed: () => Navigator.pop(context),
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
              onPressed: () => _createResidentAccount(context),
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
                  onTap: () => _showResidentDialog(context, resident),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/* ----------------------------------------------------------------
   プレースホルダー画面 (既存)
---------------------------------------------------------------- */
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
