import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FacilityDetailScreen extends StatefulWidget {
  final Map<String, dynamic> facility;
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;

  const FacilityDetailScreen({
    super.key,
    required this.facility,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore,
        _auth = auth;

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  static const _surface = Color(0xFFF7F9FB);
  static const _primary = Color(0xFF004D64);
  static const _textMuted = Color(0xFF596871);
  static const _border = Color(0xFFE2E7EB);
  static const _timeColumnWidth = 56.0;
  static const _dayColumnWidth = 44.0;
  static const _rowHeight = 42.0;
  static const _headerHeight = 74.0;

  DateTime _selectedDate = DateTime.now();
  Map<String, Map<String, bool>> _weeklyReservationStatus = {};
  bool _isLoading = false;
  final ScrollController _calendarVerticalScrollController = ScrollController();
  final ScrollController _headerHorizontalScrollController =
      ScrollController();
  final ScrollController _bodyHorizontalScrollController = ScrollController();
  bool _isSyncingHorizontalScroll = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _headerHorizontalScrollController.addListener(_syncHeaderToBody);
    _bodyHorizontalScrollController.addListener(_syncBodyToHeader);
    _fetchReservationStatusForWeek(_selectedDate);
  }

  @override
  void dispose() {
    _headerHorizontalScrollController.removeListener(_syncHeaderToBody);
    _bodyHorizontalScrollController.removeListener(_syncBodyToHeader);
    _calendarVerticalScrollController.dispose();
    _headerHorizontalScrollController.dispose();
    _bodyHorizontalScrollController.dispose();
    super.dispose();
  }

  void _syncHeaderToBody() {
    if (_isSyncingHorizontalScroll ||
        !_headerHorizontalScrollController.hasClients ||
        !_bodyHorizontalScrollController.hasClients) {
      return;
    }
    _isSyncingHorizontalScroll = true;
    _bodyHorizontalScrollController.jumpTo(
      _headerHorizontalScrollController.offset.clamp(
        0.0,
        _bodyHorizontalScrollController.position.maxScrollExtent,
      ),
    );
    _isSyncingHorizontalScroll = false;
  }

  void _syncBodyToHeader() {
    if (_isSyncingHorizontalScroll ||
        !_headerHorizontalScrollController.hasClients ||
        !_bodyHorizontalScrollController.hasClients) {
      return;
    }
    _isSyncingHorizontalScroll = true;
    _headerHorizontalScrollController.jumpTo(
      _bodyHorizontalScrollController.offset.clamp(
        0.0,
        _headerHorizontalScrollController.position.maxScrollExtent,
      ),
    );
    _isSyncingHorizontalScroll = false;
  }

  Future<void> _fetchReservationStatusForWeek(DateTime startDate) async {
    setState(() => _isLoading = true);

    final newWeeklyStatus = <String, Map<String, bool>>{};
    final facilityId = widget.facility['id'];

    final unavailableSnapshot = await widget.firestore
        .collection('facilities')
        .doc(facilityId)
        .collection('unavailable_dates')
        .get();

    final unavailableMap = <String, Map<String, dynamic>>{
      for (final doc in unavailableSnapshot.docs) doc.id: doc.data(),
    };

    for (int i = 0; i < 7; i++) {
      final day = startDate.add(Duration(days: i));
      final dayOnly = DateTime(day.year, day.month, day.day);
      final dayKey = _dateKey(dayOnly);
      final dailyStatus = <String, bool>{};

      for (int hour = 0; hour < 24; hour++) {
        for (int minute = 0; minute < 60; minute += 30) {
          final time =
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
          dailyStatus[time] = false;
        }
      }

      final reservationSnapshot = await widget.firestore
          .collection('reservations')
          .where('facilityId', isEqualTo: facilityId)
          .where('date', isEqualTo: Timestamp.fromDate(dayOnly))
          .get();

      for (final doc in reservationSnapshot.docs) {
        final times = List<String>.from(doc['times'] ?? []);
        for (final time in times) {
          dailyStatus[time] = true;
        }
      }

      if (unavailableMap.containsKey(dayKey)) {
        final data = unavailableMap[dayKey]!;
        if (data['allDay'] == true) {
          for (final key in dailyStatus.keys) {
            dailyStatus[key] = true;
          }
        } else {
          final times = List<String>.from(data['unavailableTimes'] ?? []);
          for (final time in times) {
            dailyStatus[time] = true;
          }
        }
      }

      newWeeklyStatus[dayKey] = dailyStatus;
    }

    if (!mounted) return;
    setState(() {
      _weeklyReservationStatus = newWeeklyStatus;
      _isLoading = false;
    });
  }

  Future<bool> _hasConflictingReservations(
    DateTime startDate,
    String startTime,
    DateTime endDate,
    String endTime,
  ) async {
    final facilityId = widget.facility['id'];
    var day = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day);

    while (!day.isAfter(lastDay)) {
      List<String> timeRange;
      if (_isSameDate(day, startDate) && _isSameDate(day, endDate)) {
        timeRange = _generateTimeRange(startTime, endTime);
      } else if (_isSameDate(day, startDate)) {
        timeRange = _generateTimeRange(startTime, '24:00');
      } else if (_isSameDate(day, endDate)) {
        timeRange = _generateTimeRange('00:00', endTime);
      } else {
        timeRange = _generateTimeRange('00:00', '24:00');
      }

      final dateOnly = DateTime(day.year, day.month, day.day);
      final snapshot = await widget.firestore
          .collection('reservations')
          .where('facilityId', isEqualTo: facilityId)
          .where('date', isEqualTo: Timestamp.fromDate(dateOnly))
          .get();

      for (final doc in snapshot.docs) {
        final reservedTimes = List<String>.from(doc['times'] ?? []);
        for (final time in reservedTimes) {
          if (timeRange.contains(time)) return true;
        }
      }

      day = day.add(const Duration(days: 1));
    }

    return false;
  }

  void _changeWeek(int days) {
    setState(() {
      _selectedDate = days == 0
          ? _normalizeDate(DateTime.now())
          : _selectedDate.add(Duration(days: days));
    });
    _fetchReservationStatusForWeek(_selectedDate);
  }

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _buildHero(context)),
                    SliverToBoxAdapter(child: _buildSummarySection()),
                    SliverToBoxAdapter(child: _buildWeekControls()),
                    SliverToBoxAdapter(child: _buildCalendarSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _CircleActionButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final imageUrl = widget.facility['image']?.toString();
    return Stack(
      children: [
        SizedBox(
          height: 276,
          width: double.infinity,
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildHeroFallback(),
                )
              : _buildHeroFallback(),
        ),
        Container(
          height: 276,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x14000000), Color(0x9E00151E)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroFallback() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFAFDDF3), Color(0xFFEAF4F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.meeting_room_rounded,
          size: 72,
          color: Color(0xFF4B6774),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final capacity = widget.facility['capacity']?.toString();
    final description = widget.facility['description']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.facility['name']?.toString() ?? '施設名なし',
              style: const TextStyle(
                color: Color(0xFF191C1D),
                fontSize: 30,
                height: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.payments_outlined,
                  label: _buildFormattedPriceText(widget.facility),
                ),
                if (capacity != null && capacity.isNotEmpty)
                  _InfoChip(
                    icon: Icons.group_outlined,
                    label: '最大 $capacity 名',
                    secondary: true,
                  ),
              ],
            ),
            if (description != null && description.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                description.trim(),
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekControls() {
    final now = DateTime.now();
    final today = _normalizeDate(now);
    final canShowPreviousWeek = _selectedDate.isAfter(today);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '予約カレンダー',
            style: TextStyle(
              color: Color(0xFF172126),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '○ は予約可能、× は予約済みまたは利用不可です。空いている枠をタップすると予約できます。',
            style: TextStyle(
              color: _textMuted,
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF0F3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.swipe_rounded, size: 16, color: _textMuted),
                SizedBox(width: 6),
                Text(
                  '日付部分は左右にスクロールできます',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: canShowPreviousWeek
                    ? _WeekButton(
                        label: '前の週',
                        onTap: () => _changeWeek(-7),
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekButton(
                  label: '今日の日付',
                  primary: true,
                  onTap: () => _changeWeek(0),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _WeekButton(
                  label: '次の週',
                  onTap: () => _changeWeek(7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarSection() {
    final days = List<DateTime>.generate(
      7,
      (index) => _selectedDate.add(Duration(days: index)),
    );
    final timeSlots = List<String>.generate(
      48,
      (index) {
        final hour = (index ~/ 2).toString().padLeft(2, '0');
        final minute = index.isEven ? '00' : '30';
        return '$hour:$minute';
      },
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              _buildCalendarHeader(days),
              SizedBox(
                height: 420,
                child: Scrollbar(
                  controller: _calendarVerticalScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _calendarVerticalScrollController,
                    physics: const ClampingScrollPhysics(),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: _timeColumnWidth,
                          child: Column(
                            children: [
                              for (final time in timeSlots)
                                _buildTimeLabelCell(time),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Scrollbar(
                            controller: _bodyHorizontalScrollController,
                            thumbVisibility: true,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: SingleChildScrollView(
                              controller: _bodyHorizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              physics: const ClampingScrollPhysics(),
                              child: Column(
                                children: [
                                  for (var index = 0;
                                      index < timeSlots.length;
                                      index++)
                                    _buildCalendarRow(
                                      days,
                                      timeSlots[index],
                                      index,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(List<DateTime> days) {
    return Row(
      children: [
        _buildHeaderCell(
          width: _timeColumnWidth,
          child: const SizedBox.shrink(),
          background: const Color(0xFFF0F4F7),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _headerHorizontalScrollController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: days.length * _dayColumnWidth,
              child: Row(
              children: days.map((day) {
                final weekday = _getWeekday(day.weekday);
                final isSaturday = day.weekday == DateTime.saturday;
                final isSunday = day.weekday == DateTime.sunday;
                final textColor = isSunday
                    ? const Color(0xFFBA1A1A)
                    : isSaturday
                        ? _primary
                        : const Color(0xFF1C252A);
                return _buildHeaderCell(
                  width: _dayColumnWidth,
                  background: const Color(0xFFF7F9FB),
                  borderLeft: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('M/d').format(day),
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                        const SizedBox(height: 6),
                        Text(
                          weekday,
                          style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeLabelCell(String time) {
    return Container(
      width: _timeColumnWidth,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FBFC),
        border: Border(
          top: BorderSide(color: _border),
        ),
      ),
      child: Text(
        time,
        style: const TextStyle(
          color: Color(0xFF7A8790),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCalendarRow(List<DateTime> days, String time, int rowIndex) {
    return Row(
      children: [
        ...days.asMap().entries.map(
          (entry) => _buildSlotCell(
            entry.value,
            time,
            dayIndex: entry.key,
            rowIndex: rowIndex,
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCell(
    DateTime day,
    String time, {
    required int dayIndex,
    required int rowIndex,
  }) {
    final dateKey = _dateKey(day);
    final isReserved = _weeklyReservationStatus[dateKey]?[time] ?? false;
    final isToday = _isSameDate(day, DateTime.now());
    final isHourStart = time.endsWith('00');
    final backgroundColor = isToday
        ? const Color(0xFFF4FBFF)
        : dayIndex.isEven
            ? const Color(0xFFFFFFFF)
            : const Color(0xFFFBFCFD);
    final borderColor = isHourStart ? const Color(0xFFD3DCE2) : _border;

    return GestureDetector(
      onTap: isReserved ? null : () => _showReservationSheet(day, time),
      child: Container(
        width: _dayColumnWidth,
        height: _rowHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: backgroundColor,
          border: Border(
            left: const BorderSide(color: _border),
            top: BorderSide(color: borderColor),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (rowIndex == 0)
              Container(
                width: 22,
                height: 3,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color:
                      isToday ? const Color(0x33004D64) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              )
            else
              const SizedBox(height: 11),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color:
                    isReserved ? const Color(0xFFF1F4F6) : const Color(0xFFE3F4FF),
                shape: BoxShape.circle,
                border: isToday
                    ? Border.all(color: const Color(0x33004D64), width: 1)
                    : null,
              ),
              child: Icon(
                isReserved ? Icons.close_rounded : Icons.circle,
                size: isReserved ? 14 : 10,
                color: isReserved ? const Color(0xFFB9C1C8) : _primary,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell({
    required double width,
    required Widget child,
    required Color background,
    bool borderLeft = false,
  }) {
    return Container(
      width: width,
      height: _headerHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: Border(
          left: borderLeft ? const BorderSide(color: _border) : BorderSide.none,
          bottom: const BorderSide(color: _border),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  void _showReservationSheet(DateTime selectedDay, String startTime) {
    DateTime selectedEndDate = selectedDay;

    List<String> getEndTimeOptions(DateTime day, String baseTime) {
      final isSameStartDay = day.year == selectedDay.year &&
          day.month == selectedDay.month &&
          day.day == selectedDay.day;
      return _generateEndTimeOptions(
        startTime: baseTime,
        sameDayAsStart: isSameStartDay,
      );
    }

    String selectedEndTime = getEndTimeOptions(selectedEndDate, startTime).first;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final endTimeOptions = getEndTimeOptions(selectedEndDate, startTime);
            final dropdownValue = endTimeOptions.contains(selectedEndTime)
                ? selectedEndTime
                : endTimeOptions.first;
            final summary = '${DateFormat('M/d').format(selectedDay)} $startTime'
                ' - ${DateFormat('M/d').format(selectedEndDate)} $dropdownValue';

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 12,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD5DDE2),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '予約時間の選択',
                      style: TextStyle(
                        color: Color(0xFF132126),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.facility['name']?.toString() ?? '施設',
                      style: const TextStyle(
                        color: _textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF024E65),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTED SLOT',
                            style: TextStyle(
                              color: Color(0xB3FFFFFF),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            summary,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _LabeledField(
                      label: '開始日時',
                      child: Text(
                        '${DateFormat('M/d').format(selectedDay)} (${_getWeekday(selectedDay.weekday)}) $startTime',
                        style: const TextStyle(
                          color: Color(0xFF1A262C),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: '終了日',
                      child: OutlinedButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedEndDate,
                            firstDate: selectedDay,
                            lastDate: selectedDay.add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            final options = getEndTimeOptions(date, startTime);
                            setSheetState(() {
                              selectedEndDate = date;
                              selectedEndTime = options.contains(selectedEndTime)
                                  ? selectedEndTime
                                  : options.first;
                            });
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(DateFormat('yyyy/MM/dd').format(selectedEndDate)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: '終了時刻',
                      child: DropdownButtonFormField<String>(
                        initialValue: dropdownValue,
                        items: endTimeOptions
                            .map(
                              (time) => DropdownMenuItem<String>(
                                value: time,
                                child: Text(time),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setSheetState(() => selectedEndTime = value);
                          }
                        },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFF8FAFB),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              side: const BorderSide(color: _border),
                            ),
                            child: const Text('キャンセル'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () async {
                              final hasConflict = await _hasConflictingReservations(
                                selectedDay,
                                startTime,
                                selectedEndDate,
                                selectedEndTime,
                              );

                              if (!mounted || !sheetContext.mounted) return;

                              if (hasConflict) {
                                Navigator.of(sheetContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '他の方の予約と重複しています。カレンダーを確認してください。',
                                    ),
                                    backgroundColor: Color(0xFFBA1A1A),
                                  ),
                                );
                                return;
                              }

                              Navigator.of(sheetContext).pop();
                              await _reserveTimeMultiDay(
                                selectedDay,
                                startTime,
                                selectedEndDate,
                                selectedEndTime,
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: _primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('予約する'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _reserveTimeMultiDay(
    DateTime startDate,
    String startTime,
    DateTime endDate,
    String endTime,
  ) async {
    final user = widget.auth.currentUser;
    final userId = user?.uid ?? 'unknown';
    final reservedBy = user?.email ?? 'unknown_email';
    final facilityId = widget.facility['id'];
    final facilityName = widget.facility['name'] ?? '施設';

    DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

    var day = normalizeDate(startDate);
    final lastDay = normalizeDate(endDate);

    while (!day.isAfter(lastDay)) {
      List<String> times;
      String displayStartTime;
      String displayEndTime;
      if (_isSameDate(day, startDate) && _isSameDate(day, endDate)) {
        times = _generateTimeRange(startTime, endTime);
        displayStartTime = startTime;
        displayEndTime = endTime;
      } else if (_isSameDate(day, startDate)) {
        times = _generateTimeRange(startTime, '24:00');
        displayStartTime = startTime;
        displayEndTime = '24:00';
      } else if (_isSameDate(day, endDate)) {
        times = _generateTimeRange('00:00', endTime);
        displayStartTime = '00:00';
        displayEndTime = endTime;
      } else {
        times = _generateTimeRange('00:00', '24:00');
        displayStartTime = '00:00';
        displayEndTime = '24:00';
      }

      if (times.isEmpty) {
        day = day.add(const Duration(days: 1));
        continue;
      }

      final dateOnly = DateTime(day.year, day.month, day.day);

      await widget.firestore.collection('reservations').add({
        'date': Timestamp.fromDate(dateOnly),
        'facilityId': facilityId,
        'reservedBy': reservedBy,
        'userId': userId,
        'times': times,
      });

      final labelDate = '${day.month}/${day.day}';
      final labelTime = '$displayStartTime～$displayEndTime';
      await widget.firestore.collection('notifications').add({
        'message': '「$facilityName」を$labelDate $labelTime に予約しました。',
        'timestamp': Timestamp.now(),
        'read': false,
        'type': 'reservation_confirm',
        'recipients': [userId],
      });

      day = day.add(const Duration(days: 1));
    }

    await _fetchReservationStatusForWeek(_selectedDate);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「$facilityName」の予約を登録しました。'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildFormattedPriceText(Map<String, dynamic> facility) {
    final formatter = NumberFormat.decimalPattern('ja_JP');
    final rawPrice = facility['price'];
    final parsedPrice = rawPrice is num
        ? rawPrice
        : num.tryParse(rawPrice?.toString() ?? '') ?? 0;
    final price = '${formatter.format(parsedPrice)}円';

    if (facility['unitTime'] is Map &&
        facility['unitTime']['value'] != null &&
        facility['unitTime']['unit'] != null) {
      final unitValue = facility['unitTime']['value'];
      final unitLabel = switch (facility['unitTime']['unit']) {
        'min' => '分',
        'h' => '時間',
        'day' => '日',
        _ => '',
      };
      if (unitLabel.isNotEmpty) {
        return '$unitValue$unitLabel $price';
      }
    }

    return price;
  }

  bool _isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime date) => DateTime(date.year, date.month, date.day)
      .toIso8601String()
      .split('T')[0];

  List<String> _generateEndTimeOptions({
    required String startTime,
    required bool sameDayAsStart,
  }) {
    final options = <String>[];
    final startMinutes = _timeStringToMinutes(startTime);
    final firstEndMinutes =
        sameDayAsStart ? startMinutes + 30 : 0;
    final lastEndMinutes = 24 * 60;

    for (var minutes = firstEndMinutes;
        minutes <= lastEndMinutes;
        minutes += 30) {
      options.add(_minutesToTimeString(minutes));
    }

    return options;
  }

  List<String> _generateTimeRange(String startTime, String endTime) {
    final startMinutes = _timeStringToMinutes(startTime);
    final endMinutes = _timeStringToMinutes(endTime);
    final result = <String>[];

    for (var minutes = startMinutes; minutes < endMinutes; minutes += 30) {
      if (minutes >= 24 * 60) break;
      result.add(_minutesToTimeString(minutes));
    }

    return result;
  }

  int _timeStringToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  String _minutesToTimeString(int minutes) {
    final normalizedHour = minutes ~/ 60;
    final normalizedMinute = minutes % 60;
    return '${normalizedHour.toString().padLeft(2, '0')}:${normalizedMinute.toString().padLeft(2, '0')}';
  }

  String _getWeekday(int weekday) {
    switch (weekday) {
      case 1:
        return '月';
      case 2:
        return '火';
      case 3:
        return '水';
      case 4:
        return '木';
      case 5:
        return '金';
      case 6:
        return '土';
      case 7:
        return '日';
      default:
        return '';
    }
  }
}

class _CircleActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleActionButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.88),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: const Color(0xFF053F52)),
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
        color: secondary ? const Color(0xFFF1F5F7) : const Color(0xFFD8ECF7),
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

class _WeekButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _WeekButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: primary ? const Color(0xFF004D64) : const Color(0xFFEAF0F3),
          foregroundColor: primary ? Colors.white : const Color(0xFF31424D),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF66757F),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
