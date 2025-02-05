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
  List<Map<String, dynamic>> _dayTimes = [];

  @override
  void initState() {
    super.initState();
    _fetchDayTimes(_selectedDate);
  }

  void _fetchDayTimes(DateTime date) async {
    final times = await _getDayTimes(date);
    setState(() {
      _dayTimes = times;
    });
  }

  Future<List<Map<String, dynamic>>> _getDayTimes(DateTime date) async {
    final dateKey = date.toIso8601String().split('T')[0];

    final querySnapshot = await FirebaseFirestore.instance
        .collection('reservations')
        .where('facilityId', isEqualTo: widget.facility['id'])
        .where('date', isEqualTo: dateKey)
        .get();

    final reservedTimes = querySnapshot.docs
        .map((doc) => List<String>.from(doc['times'] ?? []))
        .expand((times) => times)
        .toList();

    return List.generate(96, (index) {
      final hour = index ~/ 4;
      final minute = (index % 4) * 15;
      final time =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      return {'time': time, 'reserved': reservedTimes.contains(time)};
    });
  }

  void _showCalendarDialog(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    ).then((pickedDate) {
      if (pickedDate != null) {
        setState(() {
          _selectedDate = pickedDate;
          _fetchDayTimes(pickedDate);
        });
      }
    });
  }

  void _showReservationPopup(BuildContext context, DateTime date) async {
    final times = await _getDayTimes(date);

    String? startTime;
    String? endTime;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('予約 (${date.month}/${date.day})'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('時間を選択してください'),
                const SizedBox(height: 16),
                DropdownButton<String>(
                  hint: const Text('開始時間を選択'),
                  value: startTime,
                  items: times
                      .where((time) => !time['reserved'])
                      .map<DropdownMenuItem<String>>((time) =>
                          DropdownMenuItem<String>(
                              value: time['time'], child: Text(time['time'])))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      startTime = value;
                      if (endTime != null &&
                          !_isValidTimeRange(startTime, endTime)) {
                        endTime = null;
                      }
                    });
                  },
                ),
                DropdownButton<String>(
                  hint: const Text('終了時間を選択'),
                  value: endTime,
                  items: times
                      .where((time) =>
                          !time['reserved'] &&
                          startTime != null &&
                          _isValidTimeRange(startTime, time['time']))
                      .map<DropdownMenuItem<String>>((time) =>
                          DropdownMenuItem<String>(
                              value: time['time'], child: Text(time['time'])))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      endTime = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: startTime != null && endTime != null
                    ? () async {
                        await _reserveTime(date, startTime!, endTime!);
                        Navigator.pop(context);
                        _fetchDayTimes(date);
                      }
                    : null,
                child: const Text('予約する'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _reserveTime(
      DateTime date, String startTime, String endTime) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final dateKey = date.toIso8601String().split('T')[0];

    final start = _timeStringToDateTime(startTime);
    final end = _timeStringToDateTime(endTime);

    final reservedTimes = <String>[];
    for (var current = start;
        current.isBefore(end) || current.isAtSameMomentAs(end);
        current = current.add(const Duration(minutes: 15))) {
      reservedTimes.add(
          '${current.hour.toString().padLeft(2, '0')}:${current.minute.toString().padLeft(2, '0')}');
    }

    await FirebaseFirestore.instance.collection('reservations').add({
      'facilityId': widget.facility['id'],
      'date': dateKey,
      'times': reservedTimes,
      'userId': user.uid,
      'reservedBy': user.email, // または displayName
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('予約が完了しました: $startTime - $endTime')),
    );
  }

  bool _isValidTimeRange(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return false;

    final start = _timeStringToDateTime(startTime);
    final end = _timeStringToDateTime(endTime);

    return end.isAfter(start);
  }

  DateTime _timeStringToDateTime(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(2023, 1, 1, hour, minute); // 仮の日付で変換
  }

  Widget _buildTimeTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(96, (index) {
          final hour = index ~/ 4;
          final minute = (index % 4) * 15;
          final time =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          final reserved = _dayTimes
              .any((entry) => entry['time'] == time && entry['reserved']);

          return Container(
            width: 80,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: reserved ? Colors.red : Colors.green,
            child: Center(
              child: Text(
                time,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHorizontalCalendar() {
    final today = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );

    return Column(
      children: [
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final isSelected = _selectedDate.day == day.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = day;
                    _fetchDayTimes(day);
                  });
                },
                child: Container(
                  width: MediaQuery.of(context).size.width / 5,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.orange : Colors.grey[300],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${day.month}/${day.day}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _showCalendarDialog(context),
          child: Text(
            '${days.last.month}/${days.last.day}よりも後の予約をしたい場合',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 14,
            ),
            textAlign: TextAlign.center, // テキストを中央揃え
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('施設詳細'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: widget.facility['image'] != null
                  ? Image.network(
                      widget.facility['image'],
                      height: 200,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Text('施設画像'),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.facility['name'] ?? '施設名なし',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '利用金額: ${widget.facility['price']}円',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              'ご利用日を選択:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildHorizontalCalendar(),
            const SizedBox(height: 25),
            const Text(
              '予約状況:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildTimeTable(),
            const SizedBox(height: 8),
            const Text(
              '※空いているところは緑、埋まっているところは赤',
              style: TextStyle(
                  fontSize: 12, color: Color.fromARGB(255, 92, 92, 92)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 25),
            ElevatedButton(
              onPressed: () => _showReservationPopup(context, _selectedDate),
              child: const Text('予約する'),
            ),
          ],
        ),
      ),
    );
  }
}
