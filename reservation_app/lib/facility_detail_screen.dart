import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  const FacilityDetailScreen({
    Key? key,
    required this.facility,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        auth = auth ?? FirebaseAuth.instance,
        super(key: key);

  @override
  _FacilityDetailScreenState createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, bool>> _weeklyReservationStatus = {};
  Set<String> _unavailableDateSet = {};

  // ▼ 追加：読み込み中かどうかを管理するフラグ
  bool _isLoading = false;

  final ScrollController _horizontalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchReservationStatusForWeek(_selectedDate);
  }

  // ▼ 修正：Firestore からのデータ取得前後で _isLoading を切り替える
  Future<void> _fetchReservationStatusForWeek(DateTime startDate) async {
    setState(() {
      _isLoading = true;
    });

    Map<String, Map<String, bool>> newWeeklyStatus = {};
    final facilityId = widget.facility['id'];

    // 予約不可情報を全部取得（週の全日分をまとめて）
    final unavailableSnapshot = await widget.firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('unavailable_dates')
        .get();

    // ドキュメントID（yyyy-MM-dd）とデータの Map
    final Map<String, Map<String, dynamic>> unavailableMap = {
      for (var doc in unavailableSnapshot.docs) doc.id: doc.data()
    };

    for (int i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final dayOnly = DateTime(day.year, day.month, day.day);
      final dayKey = dayOnly.toIso8601String().split('T')[0];

      final dailyStatus = <String, bool>{};

      // --------- 1️⃣ 全時間帯を初期状態（予約可能 = false）で登録 ---------
      for (int hour = 0; hour < 24; hour++) {
        for (int minute = 0; minute < 60; minute += 30) {
          final time =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          dailyStatus[time] = false; // 空き
        }
      }

      // --------- 2️⃣ 予約済み時間を × にする ---------
      final reservationSnapshot = await widget.firestore
          .collection('reservations')
          .where('facilityId', isEqualTo: facilityId)
          .where('date', isEqualTo: Timestamp.fromDate(dayOnly))
          .get();

      for (final doc in reservationSnapshot.docs) {
        final List<String> times = List<String>.from(doc['times'] ?? []);
        // for (int i = 0; i < times.length - 1; i++) {
        //   dailyStatus[times[i]] = true; // 予約済み → ×
        // }
        for (final time in times) {
          dailyStatus[time] = true;
        }
      }

      // --------- 3️⃣ 予約不可時間（管理者設定）を × にする ---------
      if (unavailableMap.containsKey(dayKey)) {
        final data = unavailableMap[dayKey]!;
        if (data['allDay'] == true) {
          // 終日不可
          for (final key in dailyStatus.keys) {
            dailyStatus[key] = true; // 全時間 ×
          }
        } else {
          final List<String> times =
              List<String>.from(data['unavailableTimes'] ?? []);
          for (final t in times) {
            dailyStatus[t] = true; // 特定時間帯 ×
          }
        }
      }

      newWeeklyStatus[dayKey] = dailyStatus;
    }

    setState(() {
      _weeklyReservationStatus = newWeeklyStatus;
      _unavailableDateSet = unavailableMap.keys.toSet();
      _isLoading = false;
    });
  }

  Future<bool> _hasConflictingReservations(DateTime startDate, String startTime,
      DateTime endDate, String endTime) async {
    final facilityId = widget.facility['id'];
    DateTime day = DateTime(startDate.year, startDate.month, startDate.day);
    final DateTime lastDay = DateTime(endDate.year, endDate.month, endDate.day);

    while (!day.isAfter(lastDay)) {
      List<String> timeRange;

      if (isSameDate(day, startDate) && isSameDate(day, endDate)) {
        timeRange = _generateTimeRange(startTime, endTime);
      } else if (isSameDate(day, startDate)) {
        timeRange = _generateTimeRange(startTime, "23:30");
      } else if (isSameDate(day, endDate)) {
        timeRange = _generateTimeRange("00:00", endTime);
      } else {
        timeRange = _generateTimeRange("00:00", "23:30");
      }

      final dateOnly = DateTime(day.year, day.month, day.day);
      final snapshot = await widget.firestore
          .collection('reservations')
          .where('facilityId', isEqualTo: facilityId)
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .get();

      for (final doc in snapshot.docs) {
        final reservedTimes = List<String>.from(doc['times'] ?? []);
        for (final t in reservedTimes) {
          if (timeRange.contains(t)) {
            return true; // かぶってる
          }
        }
      }

      day = day.add(const Duration(days: 1));
    }

    return false; // すべてOK
  }

  void _changeWeek(int days) {
    setState(() {
      if (days == 0) {
        _selectedDate = DateTime.now();
      } else {
        _selectedDate = _selectedDate.add(Duration(days: days));
      }
    });
    _fetchReservationStatusForWeek(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設詳細'),
      ),
      // ▼ 修正：_isLoading が true の間はローディングを表示、それ以外はメインのUIを表示
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildMainContent(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final canShowPreviousWeek = selectedDay.isAfter(today);

    return Padding(
      padding: const EdgeInsets.only(top: 0.0, bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 施設画像
          ClipRRect(
            borderRadius: BorderRadius.circular(0),
            child: widget.facility['image'] != null
                ? Image.network(
                    widget.facility['image'],
                    height: 200,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(child: Text('施設画像')),
                  ),
          ),
          const SizedBox(height: 16),
          // 施設名
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              widget.facility['name'] ?? '施設名なし',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          // 利用金額
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "利用金額",
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  _buildFormattedPriceText(widget.facility),
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 週移動ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (canShowPreviousWeek)
                  ElevatedButton(
                    onPressed: () => _changeWeek(-7),
                    child: const Text('前の週'),
                  ),
                ElevatedButton(
                  onPressed: () => _changeWeek(0),
                  child: const Text('今日の日付'),
                ),
                ElevatedButton(
                  onPressed: () => _changeWeek(7),
                  child: const Text('次の週'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ヘッダー
          _buildHeaderTable(context),

          // ボディ
          Expanded(child: _buildBodyTable(context)),
        ],
      ),
    );
  }

  String _buildFormattedPriceText(Map<String, dynamic> facility) {
    final price = facility['price']?.toString() ?? '不明';

    if (facility['unitTime'] != null &&
        facility['unitTime']['value'] != null &&
        facility['unitTime']['unit'] != null) {
      final unitValue = facility['unitTime']['value'];
      final unitKey = facility['unitTime']['unit'];

      String unitLabel;
      switch (unitKey) {
        case 'min':
          unitLabel = '分';
          break;
        case 'h':
          unitLabel = '時間';
          break;
        case 'day':
          unitLabel = '日';
          break;
        default:
          unitLabel = '';
      }

      return '${unitValue}${unitLabel}　${price}円';
    }

    // unitTimeがない場合は元のまま
    return '利用金額: ${price}円';
  }

  Widget _buildHeaderTable(BuildContext context) {
    const totalColumns = 8; // 時間1 + 日付7
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final columnWidth = totalWidth / totalColumns;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          controller: _horizontalScrollController,
          child: DataTable(
            columnSpacing: 0,
            horizontalMargin: 0,
            border: TableBorder.all(color: Colors.black),
            columns: [
              DataColumn(
                label: SizedBox(
                  width: columnWidth,
                  child: const Center(
                    child: Text(
                      "時間",
                      style:
                          TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              ...List.generate(7, (index) {
                final day = _selectedDate.add(Duration(days: index));
                return DataColumn(
                  label: SizedBox(
                    width: columnWidth,
                    child: Center(
                      child: Text(
                        "${day.month}/${day.day}\n(${_getWeekday(day.weekday)})",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
            rows: const [],
          ),
        );
      },
    );
  }

  Widget _buildBodyTable(BuildContext context) {
    const totalColumns = 8;
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final columnWidth = totalWidth / totalColumns;

        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          physics: const ClampingScrollPhysics(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            controller: _horizontalScrollController,
            child: DataTable(
              headingRowHeight: 0,
              columnSpacing: 0,
              horizontalMargin: 0,
              border: TableBorder.all(color: Colors.black),
              columns: [
                DataColumn(
                  label: SizedBox(width: columnWidth),
                ),
                ...List.generate(7, (index) {
                  return DataColumn(
                    label: SizedBox(width: columnWidth),
                  );
                })
              ],
              rows: List.generate(48, (hourIndex) {
                final hourStr = (hourIndex ~/ 2).toString().padLeft(2, '0');
                final minuteStr = hourIndex % 2 == 0 ? '00' : '30';
                final time = "$hourStr:$minuteStr";

                return DataRow(
                  cells: [
                    // 左端の時間セル
                    DataCell(
                      SizedBox(
                        width: columnWidth,
                        child: Center(
                          child: Text(
                            time,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    // 7日分
                    ...List.generate(7, (dayIndex) {
                      final day = _selectedDate.add(Duration(days: dayIndex));
                      final dateKey = DateTime(day.year, day.month, day.day)
                          .toIso8601String()
                          .split('T')[0];

                      final isReserved =
                          _weeklyReservationStatus[dateKey]?[time] ?? false;

                      return DataCell(
                        SizedBox(
                          width: columnWidth,
                          child: GestureDetector(
                            onTap: (!isReserved)
                                ? () {
                                    _showReservationDialog(day, time);
                                  }
                                : null,
                            child: Center(
                              child: Text(
                                isReserved ? '×' : '◯',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }

  void _showReservationDialog(DateTime selectedDay, String startTime) async {
    // 初期値
    DateTime selectedEndDate = selectedDay;
    String selectedEndTime = startTime;

    // 終了時刻候補を生成（同じ日なら開始時刻以降、別の日なら 00:00～23:30）
    List<String> _getEndTimeOptions(DateTime day, String baseTime) {
      // 「day」が開始日(selectedDay)と同じなら開始時刻以降、
      // 違う日なら深夜0時以降をすべて表示
      final bool isSameStartDay = day.year == selectedDay.year &&
          day.month == selectedDay.month &&
          day.day == selectedDay.day;

      final String start = isSameStartDay ? baseTime : "00:00";
      const String endLimit = "23:30";
      return _generateTimeRange(start, endLimit);
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: const Text("予約時間の選択"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center, // ← 追加
              children: [
                // 開始情報
                Text(
                    "開始日: ${selectedDay.month}/${selectedDay.day} (${_getWeekday(selectedDay.weekday)})"),
                Text("開始時刻: $startTime"),
                const SizedBox(height: 12),

                // ➊ 終了日ピッカー
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("終了日: "),
                    TextButton(
                      onPressed: () async {
                        final dt = await showDatePicker(
                          context: context,
                          initialDate: selectedEndDate,
                          firstDate: selectedDay,
                          lastDate: selectedDay.add(const Duration(days: 30)),
                        );
                        if (dt != null) {
                          setState(() => selectedEndDate = dt);
                          // 終了時刻も念のためリセット
                          final opts = _getEndTimeOptions(dt, startTime);
                          selectedEndTime =
                              opts.contains(startTime) ? startTime : opts.first;
                        }
                      },
                      child: Text(
                          "${selectedEndDate.month}/${selectedEndDate.day}"),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ➋ 終了時刻ドロップダウン
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("終了時刻: "),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedEndTime,
                      items: _getEndTimeOptions(selectedEndDate, startTime)
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => selectedEndTime = v);
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("キャンセル")),
              ElevatedButton(
                onPressed: () async {
                  final hasConflict = await _hasConflictingReservations(
                      selectedDay, startTime, selectedEndDate, selectedEndTime);

                  if (hasConflict) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('他の方の予約と重複しています。カレンダーを確認してください。'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(ctx);
                  await _reserveTimeMultiDay(
                      selectedDay, startTime, selectedEndDate, selectedEndTime);
                },
                child: const Text("予約する"),
              ),
            ],
          );
        });
      },
    );
  }

  /// startDate→endDate の各日ごとに分割して予約を登録
  Future<void> _reserveTimeMultiDay(
    DateTime startDate,
    String startTime,
    DateTime endDate,
    String endTime,
  ) async {
    final user = widget.auth.currentUser;
    final userId = user?.uid ?? "unknown";
    final reservedBy = user?.email ?? "unknown_email";
    final facilityId = widget.facility['id'];
    final facilityName = widget.facility['name'] ?? '施設';

    DateTime normalizeDate(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

    DateTime day = normalizeDate(startDate);
    final DateTime lastDay = normalizeDate(endDate);

    while (!day.isAfter(lastDay)) {
      List<String> times;

      if (isSameDate(day, startDate) && isSameDate(day, endDate)) {
        times = _generateTimeRange(startTime, endTime);
      } else if (isSameDate(day, startDate)) {
        times = _generateTimeRange(startTime, "23:30");
      } else if (isSameDate(day, endDate)) {
        times = _generateTimeRange("00:00", endTime);
      } else {
        times = _generateTimeRange("00:00", "23:30");
      }

      print("🗓️ ${day.toIso8601String()} に登録する time: $times");

      if (times.isEmpty) {
        times = [startTime];
      }

      final dateOnly = DateTime(day.year, day.month, day.day);

      await widget.firestore.collection('reservations').add({
        'date': Timestamp.fromDate(dateOnly),
        'facilityId': facilityId,
        'reservedBy': reservedBy,
        'userId': userId,
        'times': times,
      });

      final labelDate = "${day.month}/${day.day}";
      final labelTime = "${times.first}～${times.last}";
      await widget.firestore.collection('notifications').add({
        'message': "「$facilityName」を$labelDate $labelTime に予約しました。",
        'timestamp': Timestamp.now(),
        'read': false,
        'type': 'reservation_confirm',
        'recipients': [userId],
      });

      day = day.add(const Duration(days: 1));
    }

    await _fetchReservationStatusForWeek(_selectedDate);
  }

  bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<String> _generateTimeRange(String startTime, String endTime) {
    final startParts = startTime.split(':');
    int startHour = int.parse(startParts[0]);
    int startMinute = int.parse(startParts[1]);

    final endParts = endTime.split(':');
    int endHour = int.parse(endParts[0]);
    int endMinute = int.parse(endParts[1]);

    List<String> result = [];

    int currentHour = startHour;
    int currentMinute = startMinute;

    while (true) {
      final timeStr =
          "${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}";

      result.add(timeStr);

      // 終了条件に達していたらループ終了（※追加後にbreak）
      if (currentHour == endHour && currentMinute == endMinute) break;

      currentMinute += 30;
      if (currentMinute >= 60) {
        currentHour++;
        currentMinute = 0;
      }

      // 無限ループ防止
      if (currentHour > 23) break;
    }

    return result;
  }

  List<String> _generateEndTimeOptions(DateTime selectedDay, String startTime) {
    final dateKey = selectedDay.toIso8601String().split('T')[0];
    final startParts = startTime.split(':');
    int currentHour = int.parse(startParts[0]);
    int currentMinute = int.parse(startParts[1]);

    List<String> options = [];
    final dailyStatus = _weeklyReservationStatus[dateKey];

    if (dailyStatus == null) {
      // 予約なし -> 24:00まで
      for (int hour = currentHour; hour < 24; hour++) {
        for (int minute = (hour == currentHour ? currentMinute : 0);
            minute < 60;
            minute += 30) {
          final timeStr =
              "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
          options.add(timeStr);
        }
      }
      return options;
    }

    while (true) {
      final currentTimeStr =
          "${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}";
      options.add(currentTimeStr);

      int nextHour = currentHour;
      int nextMinute = currentMinute + 30;
      if (nextMinute >= 60) {
        nextHour++;
        nextMinute -= 60;
      }
      if (nextHour >= 24) {
        break;
      }

      final nextTimeStr =
          "${nextHour.toString().padLeft(2, '0')}:${nextMinute.toString().padLeft(2, '0')}";

      // 次のコマが予約済みになっていたら、そこで打ち切り
      if (dailyStatus[nextTimeStr] == true) {
        options.add(nextTimeStr);
        break;
      }

      currentHour = nextHour;
      currentMinute = nextMinute;
    }

    return options;
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return "月";
      case 2:
        return "火";
      case 3:
        return "水";
      case 4:
        return "木";
      case 5:
        return "金";
      case 6:
        return "土";
      case 7:
        return "日";
      default:
        return "";
    }
  }
}
