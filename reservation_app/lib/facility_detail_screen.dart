import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> facility;

  const FacilityDetailScreen({Key? key, required this.facility})
      : super(key: key);

  @override
  _FacilityDetailScreenState createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, bool>> _weeklyReservationStatus = {};

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

    for (int i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final dayOnly = DateTime(day.year, day.month, day.day);
      final dayKey = dayOnly.toIso8601String().split('T')[0];

      final querySnapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('facilityId', isEqualTo: widget.facility['id'])
          .where('date', isEqualTo: Timestamp.fromDate(dayOnly))
          .get();

      final dailyStatus = <String, bool>{};
      for (final doc in querySnapshot.docs) {
        final List<String> times = List<String>.from(doc['times'] ?? []);
        // 最後の時間（endTime）は表示には含めない
        for (int i = 0; i < times.length - 1; i++) {
          dailyStatus[times[i]] = true;
        }
      }

      newWeeklyStatus[dayKey] = dailyStatus;
    }

    setState(() {
      _weeklyReservationStatus = newWeeklyStatus;
      _isLoading = false;
    });
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
        case 'm':
          unitLabel = '分';
          break;
        case 'h':
          unitLabel = '時間';
          break;
        case 'd':
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
                            onTap: !isReserved
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
    String _selectedEndTime = startTime;
    final endTimeOptions = _generateEndTimeOptions(selectedDay, startTime);
    final dateString =
        "${selectedDay.month}/${selectedDay.day} (${_getWeekday(selectedDay.weekday)})";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("予約時間の選択"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("日付: $dateString"),
                const SizedBox(height: 8),
                Text("開始時刻: $startTime"),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("終了時刻: "),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedEndTime,
                      items: endTimeOptions.map((time) {
                        return DropdownMenuItem<String>(
                          value: time,
                          child: Text(
                            time,
                            textAlign: TextAlign.center,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedEndTime = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("キャンセル"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _reserveTime(selectedDay, startTime, _selectedEndTime);
                  Navigator.of(context).pop();
                },
                child: const Text("予約する"),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _reserveTime(
      DateTime selectedDay, String startTime, String endTime) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? "unknown_user";
      final reservedBy = user?.email ?? "unknown_email";

      final timesToReserve = _generateTimeRange(startTime, endTime);
      final dateOnly =
          DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      await FirebaseFirestore.instance.collection('reservations').add({
        'date': Timestamp.fromDate(dateOnly),
        'facilityId': widget.facility['id'],
        'reservedBy': reservedBy,
        'userId': userId,
        'times': timesToReserve,
      });

      // 予約が完了したら再読み込み
      await _fetchReservationStatusForWeek(_selectedDate);
    } catch (e) {
      print("Error reserving time: $e");
    }
  }

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

      // ループ終了条件：endTimeに到達したらそのスロットを追加して終了
      if (currentHour == endHour && currentMinute == endMinute) {
        break;
      }

      currentMinute += 30;
      if (currentMinute >= 60) {
        currentHour++;
        currentMinute = 0;
      }

      // 念のため（無限ループ防止）
      if (currentHour > 23 || (currentHour == 23 && currentMinute > 30)) {
        break;
      }
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
