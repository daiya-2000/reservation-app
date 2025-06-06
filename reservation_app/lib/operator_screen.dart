import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// 画像選択 + Firebase Storage
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
// kIsWeb 判定
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File; // モバイルで使う
import 'dart:typed_data'; // Webで使う Uint8List
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class OperatorScreen extends StatefulWidget {
  const OperatorScreen({Key? key}) : super(key: key);

  @override
  _OperatorScreenState createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  int _selectedIndex = 0;
  String? _apartmentId;

  bool _isFirstBuild = true; // ★ 初回だけ実行するためのフラグ

  List<Widget> get _pages => [
        HomeScreen(apartmentId: _apartmentId ?? ''),
        FacilityCalendarScreen(apartmentId: _apartmentId ?? ''),
        BulletinBoardScreen(apartmentId: _apartmentId ?? ''),
        AccountScreen(apartmentId: _apartmentId ?? ''),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isFirstBuild) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is String) {
        setState(() {
          _apartmentId = args;
        });
      } else {
        // 引数がない場合（BuildingAdminと想定）、ログインユーザーのFirestore情報から取得
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .then((doc) {
            if (doc.exists) {
              final data = doc.data();
              final apartment = data?['apartment'];
              if (apartment != null && mounted) {
                setState(() {
                  _apartmentId = apartment;
                });
              }
            }
          });
        }
      }

      _isFirstBuild = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_apartmentId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'マンション管理者ダッシュボード',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
        ),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) async {
              if (index == 4) {
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
                icon: Icon(Icons.home),
                label: Text('ホーム',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today),
                label: Text('施設カレンダー',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.message),
                label: Text('掲示板',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_circle),
                label: Text('住人アカウント一覧',
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

/* ----------------------------------------------------------------
   ホーム画面
---------------------------------------------------------------- */
class HomeScreen extends StatelessWidget {
  final String apartmentId;
  const HomeScreen({Key? key, required this.apartmentId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ホーム',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
        centerTitle: true, // ★ タイトルを中央に表示
        automaticallyImplyLeading: false, // ← 戻る矢印が出ないように（念のため）
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDashboardCard(
              title: '施設予約状況表示',
              buttonText: 'もっと見る',
              onPressed: () =>
                  _showTodayAndTomorrowReservations(context, apartmentId),
            ),
          ],
        ),
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

void _showTodayAndTomorrowReservations(
    BuildContext context, String apartmentId) async {
  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));
  final List<DateTime> targetDates = [today, tomorrow];
  final Map<String, List<Map<String, String>>> reservationsByDate = {};

  for (final date in targetDates) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final snapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('apartmentId', isEqualTo: apartmentId)
        .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
        .get();

    final List<Map<String, String>> reservations = [];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final times = List<String>.from(data['times'] ?? []);
      if (times.isEmpty) continue;
      times.sort();

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

      reservations.add({
        'interval': '${times.first} ~ ${_addThirtyMinutes(times.first)}',
        'roomNumber': roomNumber,
        'userName': userName,
      });
    }

    reservationsByDate[DateFormat('yyyy/MM/dd').format(dateOnly)] =
        reservations;
  }

  showDialog(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('本日と翌日の予約状況'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: reservationsByDate.entries.map((entry) {
              final dateStr = entry.key;
              final reservations = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (reservations.isEmpty)
                      const Text('予約なし')
                    else
                      ...reservations.map((r) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                            child: Text(
                                '${r['interval']} - ${r['roomNumber']}号室 ${r['userName']}'),
                          )),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('閉じる'),
          )
        ],
      );
    },
  );
}

String _addThirtyMinutes(String time) {
  final parts = time.split(':');
  int hour = int.parse(parts[0]);
  int minute = int.parse(parts[1]);

  minute += 30;
  if (minute >= 60) {
    hour += 1;
    minute -= 60;
  }

  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/* ----------------------------------------------------------------
   施設カレンダー画面 (メイン)
---------------------------------------------------------------- */
class FacilityCalendarScreen extends StatefulWidget {
  final String apartmentId;
  const FacilityCalendarScreen({Key? key, required this.apartmentId})
      : super(key: key);

  @override
  _FacilityCalendarScreenState createState() => _FacilityCalendarScreenState();
}

class _FacilityCalendarScreenState extends State<FacilityCalendarScreen> {
  List<Map<String, dynamic>> _facilities = [];
  String? _selectedFacilityId;
  Set<String> _unavailableDays = {};
  Map<int, List<String>> _alreadyUnavailableTimesByDay = {};

  Future<void> _fetchUnavailableTimesForDay(int day) async {
    if (_selectedFacilityId == null) return;

    final dateStr =
        '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    final docSnapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(_selectedFacilityId)
        .collection('unavailable_dates')
        .doc(dateStr)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      final List<dynamic> times = data?['unavailableTimes'] ?? [];
      _alreadyUnavailableTimesByDay[day] = List<String>.from(times);
    } else {
      _alreadyUnavailableTimesByDay[day] = [];
    }
  }

  final List<String> kDefaultTimeSlots = [
    for (int h = 0; h < 24; h++)
      for (int m = 0; m < 60; m += 30)
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}'
  ];

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
    final snapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .where('apartment_id', isEqualTo: widget.apartmentId)
        .get();

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

    final unavailableSnapshot = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(_selectedFacilityId)
        .collection('unavailable_dates')
        .get();

    setState(() {
      _unavailableDays = unavailableSnapshot.docs
          .map((doc) => doc.id) // yyyy-MM-dd そのまま
          .toSet();
      _alreadyUnavailableTimesByDay.clear(); // ←★ 追加！
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

  void _deleteFacility() {
    if (_selectedFacilityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除する施設が選択されていません。')),
      );
      return;
    }

    final selectedFacility = _facilities.firstWhere(
      (facility) => facility['id'] == _selectedFacilityId,
      orElse: () => {},
    );

    final facilityName = selectedFacility['name'] ?? '名称不明';

    // 外側の context を保持
    final parentContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('施設削除の確認'),
          content: Text('「$facilityName」を削除しますか？この操作は元に戻せません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // ダイアログを閉じる

                try {
                  await FirebaseFirestore.instance
                      .collection('facilities')
                      .doc(_selectedFacilityId)
                      .delete();

                  await _fetchFacilities();

                  Future.delayed(Duration.zero, () {
                    if (mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        const SnackBar(content: Text('施設を削除しました。')),
                      );
                    }
                  });
                } catch (e) {
                  Future.delayed(Duration.zero, () {
                    if (mounted) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(content: Text('削除に失敗しました: $e')),
                      );
                    }
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

  // カレンダー編集
  void _editCalendar() {
    if (_selectedFacilityId == null) return;

    showDialog(
      context: context,
      builder: (context) {
        final year = _selectedMonth.year;
        final month = _selectedMonth.month;
        final daysInMonth = DateUtils.getDaysInMonth(year, month);

        int selectedDay = 1;
        bool allDay = true;
        String startTime = '00:00';
        String endTime = '23:30';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('予約不可日・時間を設定'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 日付選択
                    Wrap(
                      spacing: 8,
                      children: List.generate(daysInMonth, (index) {
                        final day = index + 1;
                        return ChoiceChip(
                          label: Text('$day日'),
                          selected: selectedDay == day,
                          onSelected: (selected) async {
                            if (selected) {
                              setStateDialog(() {
                                selectedDay = day;
                              });
                              await _fetchUnavailableTimesForDay(day);
                              setStateDialog(() {});
                            }
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    // 予約不可設定方法
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: allDay,
                          onChanged: (value) {
                            setStateDialog(() => allDay = value!);
                          },
                        ),
                        const Text('一日予約不可'),
                        Radio<bool>(
                          value: false,
                          groupValue: allDay,
                          onChanged: (value) {
                            setStateDialog(() => allDay = value!);
                          },
                        ),
                        const Text('特定時間だけ予約不可'),
                      ],
                    ),
                    if (!allDay) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('開始時間:'),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: startTime,
                            items: kDefaultTimeSlots
                                .where((time) =>
                                    !(_alreadyUnavailableTimesByDay[selectedDay]
                                            ?.contains(time) ??
                                        false))
                                .map((time) => DropdownMenuItem(
                                    value: time, child: Text(time)))
                                .toList(),
                            onChanged: (value) {
                              setStateDialog(() => startTime = value!);
                            },
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Text('終了時間:'),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: endTime,
                            items: kDefaultTimeSlots
                                .where((time) =>
                                    !(_alreadyUnavailableTimesByDay[selectedDay]
                                            ?.contains(time) ??
                                        false))
                                .map((time) => DropdownMenuItem(
                                    value: time, child: Text(time)))
                                .toList(),
                            onChanged: (value) {
                              setStateDialog(() => endTime = value!);
                            },
                          ),
                        ],
                      ),
                    ],
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
                    final parentContext = context;
                    final batch = FirebaseFirestore.instance.batch();
                    final unavailableRef = FirebaseFirestore.instance
                        .collection('facilities')
                        .doc(_selectedFacilityId)
                        .collection('unavailable_dates');

                    final dateStr =
                        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${selectedDay.toString().padLeft(2, '0')}';

                    if (allDay) {
                      batch.set(unavailableRef.doc(dateStr), {
                        'allDay': true,
                        'unavailableTimes': [],
                        'createdAt': Timestamp.now(),
                      });
                    } else {
                      final startIdx = kDefaultTimeSlots.indexOf(startTime);
                      final endIdx = kDefaultTimeSlots.indexOf(endTime);

                      if (startIdx >= endIdx) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('開始時間は終了時間より前にしてください')),
                        );
                        return;
                      }

                      final newUnavailableTimes =
                          kDefaultTimeSlots.sublist(startIdx, endIdx);

                      final existingTimes = Set<String>.from(
                          _alreadyUnavailableTimesByDay[selectedDay] ?? []);
                      final newTimesSet = Set<String>.from(newUnavailableTimes);
                      final overlap = existingTimes.intersection(newTimesSet);

                      if (overlap.isNotEmpty) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          const SnackBar(content: Text('すでに予約不可の時間帯と重複しています')),
                        );
                        return;
                      }

                      batch.set(unavailableRef.doc(dateStr), {
                        'allDay': false,
                        'unavailableTimes': [
                          ...(_alreadyUnavailableTimesByDay[selectedDay] ?? []),
                          ...newUnavailableTimes,
                        ],
                        'createdAt': Timestamp.now(),
                      });

                      _alreadyUnavailableTimesByDay[selectedDay] = [
                        ...(_alreadyUnavailableTimesByDay[selectedDay] ?? []),
                        ...newUnavailableTimes,
                      ];
                    }

                    await batch.commit();
                    Navigator.pop(parentContext);
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(content: Text('予約不可設定を保存しました')),
                    );
                    await _fetchReservationsForMonth();
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 予定のエクスポート
  void _exportSchedule() async {
    if (_selectedFacilityId == null) return;

    final selectedFacility = _facilities.firstWhere(
      (f) => f['id'] == _selectedFacilityId,
      orElse: () => {},
    );

    final facilityName = selectedFacility['name'] ?? '不明施設';
    final price = int.tryParse(selectedFacility['price'] ?? '0') ?? 0;
    final unitValue = selectedFacility['unitTime']?['value'] ?? 1;
    final unit = selectedFacility['unitTime']?['unit'] ?? 'h';

    final unitInMinutes = unit == 'h'
        ? unitValue * 60
        : unit == 'day'
            ? unitValue * 1440
            : unitValue;
    final pricePer30Min = (price / (unitInMinutes / 30)).round();

    final year = _selectedMonth.year;
    final month = _selectedMonth.month;

    final firstDay = DateTime(year, month, 1);
    final lastDay =
        DateTime(year, month + 1, 1).subtract(const Duration(days: 1));

    final query = await FirebaseFirestore.instance
        .collection('reservations')
        .where('facilityId', isEqualTo: _selectedFacilityId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(firstDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(lastDay))
        .get();

    final List<List<dynamic>> detailRows = [];
    final Map<String, Map<String, dynamic>> userMap = {};

    for (var doc in query.docs) {
      final data = doc.data();
      final userId = data['userId'] ?? '';
      final times = List<String>.from(data['times'] ?? []);
      if (times.length < 2) continue; // 1枠未満はスキップ

      final slotCount = times.length - 1;
      final totalMinutes = slotCount * 30;

// ★ ここを修正：切り上げて unitTime ごとの単位で課金
      final unitDuration = unitInMinutes; // 例: 120分 (2時間)
      final numUnits = (totalMinutes / unitDuration).ceil();
      final amount = numUnits * price;

      final timeStr = totalMinutes % 60 == 0
          ? '${totalMinutes ~/ 60}時間'
          : '${totalMinutes ~/ 60}時間${totalMinutes % 60}分';
      final date = (data['date'] as Timestamp).toDate();
      final dateStr =
          '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

      if (!userMap.containsKey(userId)) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        userMap[userId] = {
          'name': userDoc.data()?['name'] ?? '不明',
          'roomNumber': userDoc.data()?['roomNumber'] ?? '不明',
          'total': 0,
        };
      }

      final user = userMap[userId]!;
      user['total'] += amount;

      detailRows.add([
        user['roomNumber'],
        user['name'],
        dateStr,
        facilityName,
        timeStr,
        amount,
      ]);
    }

    final csvDetail = <List<dynamic>>[
      ['部屋番号', '名前', '利用日付', '利用施設名', '利用時間', '支払い金額'],
      ...detailRows
    ];

    final summaryMap = <String, Map<String, dynamic>>{};

    // 合計情報の集計
    for (var row in detailRows) {
      final roomNumber = row[0] as String;
      final timeStr = row[4] as String;
      final amount = row[5] as int;

      final match = RegExp(r'(\d+)時間(?:([0-9]+)分)?').firstMatch(timeStr);
      if (match == null) continue;

      final hours = int.parse(match.group(1)!);
      final minutes = match.group(2) != null ? int.parse(match.group(2)!) : 0;
      final totalMinutes = hours * 60 + minutes;

      summaryMap[roomNumber] ??= {
        'roomNumber': roomNumber,
        'totalTime': 0,
        'totalAmount': 0,
      };

      summaryMap[roomNumber]!['totalTime'] += totalMinutes;
      summaryMap[roomNumber]!['totalAmount'] += amount;
    }

    final csvSummary = <List<dynamic>>[
      ['部屋番号', '合計利用時間', '月の支払い合計'],
      ...summaryMap.values.map((e) => [
            e['roomNumber'],
            '${e['totalTime'] ~/ 60}時間${e['totalTime'] % 60}分',
            e['totalAmount'],
          ])
    ];

    final csvDetailText = const ListToCsvConverter().convert(csvDetail);
    final csvSummaryText = const ListToCsvConverter().convert(csvSummary);

    final encodedDetail = utf8.encode(csvDetailText);
    final encodedSummary = utf8.encode(csvSummaryText);

    final blobDetail = html.Blob([encodedDetail]);
    final blobSummary = html.Blob([encodedSummary]);

    final facilityFileName =
        facilityName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'); // ファイル名に使えない文字対策

    final detailUrl = html.Url.createObjectUrlFromBlob(blobDetail);
    final summaryUrl = html.Url.createObjectUrlFromBlob(blobSummary);

    final detailAnchor = html.AnchorElement(href: detailUrl)
      ..setAttribute('download',
          '${facilityFileName}_${year}_${month.toString().padLeft(2, '0')}_明細.csv')
      ..click();

    final summaryAnchor = html.AnchorElement(href: summaryUrl)
      ..setAttribute('download',
          '${facilityFileName}_${year}_${month.toString().padLeft(2, '0')}_合計.csv')
      ..click();

    html.Url.revokeObjectUrl(detailUrl);
    html.Url.revokeObjectUrl(summaryUrl);
  }

  // 日付セルタップ -> その日の予約をダイアログ表示
  void _showDayReservationsDialog(int day) async {
    final year = _selectedMonth.year;
    final month = _selectedMonth.month.toString().padLeft(2, '0');
    final dayStr = day.toString().padLeft(2, '0');
    final titleText = '$year年$month月$dayStr日の予約';

    final dateStr = '$year-$month-$dayStr'; // FirestoreのドキュメントID
    final unavailableDoc = await FirebaseFirestore.instance
        .collection('facilities')
        .doc(_selectedFacilityId)
        .collection('unavailable_dates')
        .doc(dateStr)
        .get();

    final reservations = _reservationsByDay[day] ?? [];

    if (reservations.isEmpty && !unavailableDoc.exists) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(titleText),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (unavailableDoc.exists) ...[
                  const Text(
                    '【予約不可】',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (unavailableDoc.data()?['allDay'] == true)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _confirmDeleteUnavailable(
                            dateStr, '00:00', '24:00'),
                        child: Card(
                          color: Colors.purple[50],
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(8.0),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '1日予約不可',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'クリックで予約不可取消',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: () {
                        final times = List<String>.from(
                            unavailableDoc.data()?['unavailableTimes'] ?? []);
                        List<List<String>> grouped = [];
                        List<String> currentGroup = [];

                        for (int i = 0; i < times.length; i++) {
                          final current = times[i];
                          if (currentGroup.isEmpty) {
                            currentGroup.add(current);
                          } else {
                            final last = currentGroup.last;
                            if (_addThirtyMinutes(last) == current) {
                              currentGroup.add(current);
                            } else {
                              grouped.add(currentGroup);
                              currentGroup = [current];
                            }
                          }
                        }
                        if (currentGroup.isNotEmpty) {
                          grouped.add(currentGroup);
                        }

                        return grouped.map((group) {
                          final start = group.first;
                          final end = _addThirtyMinutes(group.last);
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _confirmDeleteUnavailable(
                                  dateStr, start, end),
                              child: Card(
                                color: Colors.purple[50], // 色を統一
                                child: Container(
                                  width: 250, // ★追加
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '$start ~ $end',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'クリックで予約不可取消',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList();
                      }(),
                    ),
                  const SizedBox(height: 16),
                ],
                if (reservations.isNotEmpty) ...[
                  const Text(
                    '【予約】',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...reservations.map((r) {
                    final interval = r['interval'] ?? '不明';
                    final roomNumber = r['roomNumber'] ?? '不明';
                    final userName = r['userName'] ?? '不明';
                    return MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _confirmDeleteReservation(dateStr, r),
                        child: Card(
                          elevation: 2,
                          color: Colors.purple[50], // 色を統一
                          child: Container(
                            width: 250, // ★ここを追加（お好みで 260〜300 でもOK）
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  interval,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$roomNumber号室 $userName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'クリックで予約取消',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ],
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

  void _confirmDeleteUnavailable(
      String dateStr, String start, String end) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('予約不可を削除しますか？'),
        content: Text('時間: $start ~ $end'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除')),
        ],
      ),
    );

    if (confirmed == true) {
      Navigator.of(context).pop();
      await _deleteUnavailableTime(dateStr, start, end);
      await _fetchReservationsForMonth();
    }
  }

  Future<void> _deleteUnavailableTime(
      String dateStr, String start, String end) async {
    final docRef = FirebaseFirestore.instance
        .collection('facilities')
        .doc(_selectedFacilityId)
        .collection('unavailable_dates')
        .doc(dateStr);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    final times = List<String>.from(data['unavailableTimes'] ?? []);
    final toRemove = kDefaultTimeSlots.sublist(
        kDefaultTimeSlots.indexOf(start), kDefaultTimeSlots.indexOf(end));
    final updatedTimes = times.where((t) => !toRemove.contains(t)).toList();

    if (updatedTimes.isEmpty) {
      await docRef.delete();
    } else {
      await docRef.update({'unavailableTimes': updatedTimes});
    }
  }

  void _confirmDeleteReservation(
      String dateStr, Map<String, String> reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('予約を削除しますか？'),
        content: Text('時間: ${reservation['interval']}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('削除')),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteReservation(dateStr, reservation);
      await _fetchReservationsForMonth();
    }
  }

  Future<void> _deleteReservation(
      String dateStr, Map<String, String> reservation) async {
    final ts = Timestamp.fromDate(DateTime.parse(dateStr));
    final query = await FirebaseFirestore.instance
        .collection('reservations')
        .where('facilityId', isEqualTo: _selectedFacilityId)
        .where('date', isEqualTo: ts)
        .get();

    for (final doc in query.docs) {
      final times = List<String>.from(doc['times'] ?? []);
      if (times.isEmpty) continue;
      final interval = '${times.first} ~ ${_addThirtyMinutes(times.last)}';
      if (interval == reservation['interval']) {
        await doc.reference.delete();
        break;
      }
    }
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
      final dateStr = DateFormat('yyyy-MM-dd')
          .format(DateTime(_selectedMonth.year, _selectedMonth.month, day));
      final isUnavailable = _unavailableDays.contains(dateStr);
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isUnavailable ? Colors.red : Colors.black,
                      ),
                    ),
                    if (isUnavailable)
                      if (isUnavailable)
                        FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          future: FirebaseFirestore.instance
                              .collection('facilities')
                              .doc(_selectedFacilityId)
                              .collection('unavailable_dates')
                              .doc(dateStr)
                              .get(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Text('予約不可',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red));
                            }
                            if (!snapshot.hasData || !snapshot.data!.exists) {
                              return const Text('予約不可',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red));
                            }
                            final data = snapshot.data!.data()!;
                            if (data['allDay'] == true) {
                              return const Text('1日予約不可',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.red));
                            } else {
                              final times = List<String>.from(
                                  data['unavailableTimes'] ?? []);
                              if (times.isEmpty) {
                                return const Text('予約不可',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.red));
                              }
                              final start = times.first;
                              final end = _addThirtyMinutes(times.last);
                              return Text(
                                '$start～$end 予約不可',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red),
                              );
                            }
                          },
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
              )),
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
    final durationValueController = TextEditingController();
    String selectedUnit = 'min'; // 初期値: 分

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
                final durationValueText = durationValueController.text.trim();

                if (name.isEmpty ||
                    priceText.isEmpty ||
                    durationValueText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('全ての項目を入力してください。')),
                  );
                  return;
                }

                if (!RegExp(r'^[0-9]+$').hasMatch(priceText) ||
                    !RegExp(r'^[0-9]+$').hasMatch(durationValueText)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('価格と時間単位の数値は半角数字で入力してください。')),
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
                final apartmentId =
                    userDoc.data()?['apartment'] ?? 'unknown_apartment';

                imageUrl = await _uploadImageToStorage();

                await FirebaseFirestore.instance.collection('facilities').add({
                  'apartment_id': apartmentId,
                  'image': imageUrl,
                  'name': name,
                  'price': priceText,
                  'unitTime': {
                    'value': int.parse(durationValueText),
                    'unit': selectedUnit,
                  },
                });

                Navigator.pop(context);
                _fetchFacilities();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('施設を登録しました。')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('エラーが発生しました: $e')),
                );
              }
            }

            Widget _buildPreview() {
              if (kIsWeb && webImage != null) {
                return Image.memory(webImage!,
                    width: 100, height: 100, fit: BoxFit.cover);
              } else if (!kIsWeb && mobileImageFile != null) {
                return Image.file(File(mobileImageFile!.path),
                    width: 100, height: 100, fit: BoxFit.cover);
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationValueController,
                            decoration:
                                const InputDecoration(labelText: '単位時間'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        DropdownButton<String>(
                          value: selectedUnit,
                          items: const [
                            DropdownMenuItem(value: 'min', child: Text('分')),
                            DropdownMenuItem(value: 'h', child: Text('時間')),
                            DropdownMenuItem(value: 'day', child: Text('日')),
                          ],
                          onChanged: (value) {
                            setStateDialog(() {
                              selectedUnit = value!;
                            });
                          },
                        ),
                      ],
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
          // 施設カレンダータイトル（中央）
          const Padding(
            padding: EdgeInsets.only(bottom: 16.0),
            child: Center(
              child: Text(
                '施設カレンダー',
                style: TextStyle(
                  fontSize: 24,
                ),
              ),
            ),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側: 施設プルダウン
              Row(
                mainAxisSize: MainAxisSize.min,
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

              // ←★ 追加：左と右を分けるためのスペーサー
              const Spacer(),

              // 右側: ボタン群
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
                    onPressed: _deleteFacility,
                    child: const Text('施設削除'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: _editCalendar,
                    child: const Text('予約不可設定'),
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
   掲示板画面
---------------------------------------------------------------- */
class BulletinBoardScreen extends StatefulWidget {
  final String apartmentId;
  const BulletinBoardScreen({Key? key, required this.apartmentId})
      : super(key: key);

  @override
  State<BulletinBoardScreen> createState() => _BulletinBoardScreenState();
}

class _BulletinBoardScreenState extends State<BulletinBoardScreen> {
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bulletin_posts')
        .where('apartmentId', isEqualTo: widget.apartmentId)
        .orderBy('createdAt', descending: true)
        .get();

    final postList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id, // ← 追加
        'title': data['title'] ?? '無題',
        'body': data['body'] ?? '',
        'pdfUrl': data['pdfUrl'],
        'createdAt': data['createdAt'],
      };
    }).toList();

    setState(() {
      _posts = postList;
    });
  }

  void _showCreatePostDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    // ここで定義（null許容型）
    PlatformFile? selectedPdfFile;
    String? selectedPdfName;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            title: const Text('掲示板を作成'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'タイトル'),
                  ),
                  TextField(
                    controller: bodyController,
                    decoration: const InputDecoration(labelText: '本文'),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                          withData: true,
                        );

                        if (result != null && result.files.isNotEmpty) {
                          final file = result.files.first;

                          // setStateで状態更新（ダイアログ内のUI再描画）
                          setModalState(() {
                            selectedPdfFile = file;
                            selectedPdfName = file.name;
                          });
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('ファイル選択に失敗しました: $e')),
                        );
                      }
                    },
                    child: const Text('詳細PDFアップロードボタン'),
                  ),
                  if (selectedPdfName != null) Text('ファイル名：$selectedPdfName'),
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
                  final title = titleController.text.trim();
                  final body = bodyController.text.trim();
                  if (title.isEmpty || body.isEmpty) return;

                  String? pdfUrl;

                  if (selectedPdfFile != null &&
                      selectedPdfFile!.bytes != null) {
                    final storageRef = FirebaseStorage.instance
                        .ref()
                        .child('bulletins/${selectedPdfFile!.name}');
                    final uploadTask = await storageRef.putData(
                      selectedPdfFile!.bytes!,
                      SettableMetadata(contentType: 'application/pdf'),
                    );
                    pdfUrl = await storageRef.getDownloadURL();
                  }

                  await FirebaseFirestore.instance
                      .collection('bulletin_posts')
                      .add({
                    'title': title,
                    'body': body,
                    'pdfUrl': pdfUrl,
                    'apartmentId': widget.apartmentId,
                    'createdAt': Timestamp.now(),
                  });

                  // ダイアログを閉じる前にスナックバーを表示
                  Navigator.pop(context);

                  // スナックバー表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('投稿が完了しました')),
                  );

                  _fetchPosts();
                },
                child: const Text('作成ボタン'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post) {
    final ts = post['createdAt'] as Timestamp;
    final dt = ts.toDate();
    final formatted = DateFormat('yyyy/MM/dd HH:mm').format(dt);

    return MouseRegion(
      cursor: SystemMouseCursors.click, // ← カーソルを手の形に
      child: GestureDetector(
        onTap: () => _showPostDetailDialog(post),
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(post['title'],
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(formatted,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 12),
                Text(post['body']),
                if (post['pdfUrl'] != null) ...[
                  const SizedBox(height: 12),
                  const Text('PDFあり', style: TextStyle(color: Colors.blue)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post['title']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(post['body']),
            const SizedBox(height: 16),
            if (post['pdfUrl'] != null)
              TextButton(
                onPressed: () async {
                  final url = Uri.parse(post['pdfUrl']);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('PDFを開けませんでした')),
                    );
                  }
                },
                child: const Text('PDFを表示'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditPostDialog(post);
            },
            child: const Text('編集'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('bulletin_posts')
                  .doc(post['id'])
                  .delete();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿を削除しました')),
              );
              _fetchPosts();
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(Map<String, dynamic> post) {
    final titleController = TextEditingController(text: post['title']);
    final bodyController = TextEditingController(text: post['body']);

    PlatformFile? selectedPdfFile;
    String? selectedPdfName;
    String? originalPdfUrl = post['pdfUrl'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('掲示板を編集'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'タイトル'),
                ),
                TextField(
                  controller: bodyController,
                  decoration: const InputDecoration(labelText: '本文'),
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setModalState(() {
                          selectedPdfFile = result.files.first;
                          selectedPdfName = selectedPdfFile!.name;
                        });
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('PDF選択に失敗しました: $e')),
                      );
                    }
                  },
                  child: const Text('PDFを再アップロード'),
                ),
                if (selectedPdfName != null) Text('ファイル名：$selectedPdfName'),
                if (selectedPdfName == null && originalPdfUrl != null)
                  const Text('現在のPDFが登録されています'),
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
                final updatedTitle = titleController.text.trim();
                final updatedBody = bodyController.text.trim();
                if (updatedTitle.isEmpty || updatedBody.isEmpty) return;

                String? updatedPdfUrl = originalPdfUrl;

                if (selectedPdfFile != null && selectedPdfFile!.bytes != null) {
                  final storageRef = FirebaseStorage.instance
                      .ref()
                      .child('bulletins/${selectedPdfFile!.name}');
                  await storageRef.putData(
                    selectedPdfFile!.bytes!,
                    SettableMetadata(contentType: 'application/pdf'),
                  );
                  updatedPdfUrl = await storageRef.getDownloadURL();
                }

                await FirebaseFirestore.instance
                    .collection('bulletin_posts')
                    .doc(post['id'])
                    .update({
                  'title': updatedTitle,
                  'body': updatedBody,
                  'pdfUrl': updatedPdfUrl,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('投稿を更新しました')),
                );
                _fetchPosts();
              },
              child: const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              '掲示板',
              style: TextStyle(fontSize: 24),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: _showCreatePostDialog,
              child: const Text('新規掲示板作成'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _posts.isEmpty
                ? const Center(child: Text('まだ掲示はありません'))
                : ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      return _buildPostCard(_posts[index]);
                    },
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
  final String apartmentId;
  const AccountScreen({Key? key, required this.apartmentId}) : super(key: key);

  Future<List<Map<String, dynamic>>> _fetchResidents(String apartmentId) async {
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
                    'apartment':
                        apartmentId, // ← ここを修正して context で受け取った apartmentId を使用
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
        automaticallyImplyLeading: false,
        title: const Text(
          '住人アカウント一覧',
          style: TextStyle(
            fontSize: 24,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _createResidentAccount(context),
              child: const Text('新規住人アカウント作成'),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchResidents(apartmentId),
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
                        leading: const Icon(Icons.person),
                        title: Text(resident['name'] ?? '名前不明'),
                        subtitle:
                            Text('部屋番号: ${resident['roomNumber'] ?? '不明'}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _showResidentDialog(context, resident),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
