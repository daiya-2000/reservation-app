import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

class OperatorScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const OperatorScreen({
    super.key,
    required this.auth,
    required this.firestore,
    required this.functions,
  });

  @override
  State<OperatorScreen> createState() => _OperatorScreenState();
}

class _OperatorScreenState extends State<OperatorScreen> {
  static const _shellBackground = Color(0xFFF6F8FB);
  static const _shellPrimary = Color(0xFF0C5D78);
  static const _shellPrimaryDark = Color(0xFF083F53);
  static const _shellText = Color(0xFF18242D);

  int _selectedIndex = 0;
  String? _apartmentId;
  String? _apartmentName;

  bool _isFirstBuild = true; // ★ 初回だけ実行するためのフラグ

  List<Widget> get _pages => [
        HomeScreen(
          apartmentId: _apartmentId!,
          apartmentName: _apartmentName,
          firestore: widget.firestore,
        ),
        FacilityCalendarScreen(
          apartmentId: _apartmentId!,
          auth: widget.auth,
          firestore: widget.firestore,
          functions: widget.functions,
        ),
        BulletinBoardScreen(
          apartmentId: _apartmentId!,
          firestore: widget.firestore,
          functions: widget.functions,
        ),
        AccountScreen(
          apartmentId: _apartmentId!,
          auth: widget.auth,
          firestore: widget.firestore,
          functions: widget.functions,
        ),
        ContactScreen(
          apartmentId: _apartmentId!,
          firestore: widget.firestore,
        ),
        ProfileScreen(
          auth: widget.auth,
        ),
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isFirstBuild) {
      final args = ModalRoute.of(context)?.settings.arguments;

      if (args is String) {
        _setApartmentInfo(args);
      } else {
        // 引数がない場合（BuildingAdminと想定）、ログインユーザーのFirestore情報から取得
        final user = widget.auth.currentUser;
        if (user != null) {
          widget.firestore.collection('users').doc(user.uid).get().then((doc) {
            if (doc.exists) {
              final data = doc.data();
              final apartment = data?['apartment'];
              if (apartment != null) {
                _setApartmentInfo(apartment.toString());
              }
            }
          });
        }
      }

      _isFirstBuild = false;
    }
  }

  Future<void> _setApartmentInfo(String apartmentId) async {
    if (!mounted) return;
    setState(() {
      _apartmentId = apartmentId;
    });

    try {
      final apartmentDoc = await widget.firestore
          .collection('apartments')
          .doc(apartmentId)
          .get();
      final apartmentName = apartmentDoc.data()?['name']?.toString().trim();
      if (!mounted) return;
      setState(() {
        _apartmentName =
            apartmentName != null && apartmentName.isNotEmpty
                ? apartmentName
                : apartmentId;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _apartmentName = apartmentId;
      });
    }
  }

  Future<void> _handleDestinationSelected(int index) async {
    if (index == 6) {
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
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ログアウト'),
            ),
          ],
        ),
      );

      if (shouldLogout == true) {
        await widget.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
      }
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  List<_OperatorNavItem> get _navigationItems => const [
        _OperatorNavItem(
          label: 'ホーム',
          icon: Icons.home_rounded,
          hint: 'ダッシュボード',
        ),
        _OperatorNavItem(
          label: '施設カレンダー',
          icon: Icons.calendar_month_rounded,
          hint: '予約と施設管理',
        ),
        _OperatorNavItem(
          label: '掲示板',
          icon: Icons.forum_rounded,
          hint: 'お知らせ運用',
        ),
        _OperatorNavItem(
          label: '住人アカウント一覧',
          icon: Icons.groups_rounded,
          hint: '居住者管理',
        ),
        _OperatorNavItem(
          label: 'お問い合わせ',
          icon: Icons.support_agent_rounded,
          hint: '回答対応',
        ),
        _OperatorNavItem(
          label: 'プロフィール',
          icon: Icons.person_rounded,
          hint: 'アカウント設定',
        ),
        _OperatorNavItem(
          label: 'ログアウト',
          icon: Icons.logout_rounded,
          hint: 'セッション終了',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    if (_apartmentId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final activeItem = _navigationItems[_selectedIndex];

    return Scaffold(
      backgroundColor: _shellBackground,
      body: Row(
        children: [
          Container(
            width: 272,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _shellPrimaryDark,
                  _shellPrimary,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(8, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Building Admin',
                            style: TextStyle(
                              color: Color(0xFFB9E6F5),
                              fontSize: 12,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'マンション管理\nダッシュボード',
                            style: TextStyle(
                              color: Colors.white,
                              height: 1.15,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            '施設、掲示板、住民対応を1つの画面から管理します。',
                            style: TextStyle(
                              color: Color(0xFFCBE5EF),
                              fontSize: 13,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'MAIN MENU',
                      style: TextStyle(
                        color: Color(0xFFB9E6F5),
                        fontSize: 11,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _navigationItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = _navigationItems[index];
                          final selected = index == _selectedIndex;
                          return _OperatorSidebarButton(
                            item: item,
                            selected: selected,
                            onTap: () => _handleDestinationSelected(index),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
                  decoration: const BoxDecoration(
                    color: _shellBackground,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8EE)),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeItem.label,
                                style: const TextStyle(
                                  color: _shellText,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.9,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                activeItem.hint,
                                style: const TextStyle(
                                  color: Color(0xFF63727C),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: const Color(0xFFDCE5EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.apartment_rounded,
                                size: 18,
                                color: _shellPrimary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _apartmentName ?? _apartmentId ?? '',
                                style: const TextStyle(
                                  color: _shellText,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: _pages[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ----------------------------------------------------------------
   ホーム画面
---------------------------------------------------------------- */
class HomeScreen extends StatelessWidget {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);

  final String apartmentId;
  final String? apartmentName;
  final FirebaseFirestore firestore;

  const HomeScreen({
    Key? key,
    required this.apartmentId,
    required this.apartmentName,
    required this.firestore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE7F5FB),
                    Colors.white,
                    Color(0xFFF5FBFE),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x14004D64),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'ADMIN HOME',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 12,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '本日の運用状況を\nひと目で確認できます。',
                    style: TextStyle(
                      color: Color(0xFF18242D),
                      fontSize: 34,
                      height: 1.12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '施設予約、居住者数、お問い合わせ状況を ${apartmentName ?? apartmentId} の運用単位でまとめて確認できます。',
                    style: const TextStyle(
                      color: Color(0xFF5A6973),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FutureBuilder<_OperatorDashboardSummary>(
              future: _fetchSummary(),
              builder: (context, snapshot) {
                final summary = snapshot.data;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _DashboardMetricCard(
                      title: '施設数',
                      value: summary != null ? '${summary.facilityCount}' : '...',
                      subtitle: '公開中の共用施設',
                      icon: Icons.apartment_rounded,
                    ),
                    _DashboardMetricCard(
                      title: '予約件数',
                      value:
                          summary != null ? '${summary.todayReservationCount}' : '...',
                      subtitle: '本日の予約件数',
                      icon: Icons.calendar_month_rounded,
                    ),
                    _DashboardMetricCard(
                      title: '住人数',
                      value: summary != null ? '${summary.residentCount}' : '...',
                      subtitle: '登録済み居住者',
                      icon: Icons.groups_rounded,
                    ),
                    _DashboardMetricCard(
                      title: '未対応',
                      value: summary != null ? '${summary.openContactCount}' : '...',
                      subtitle: '対応中のお問い合わせ',
                      icon: Icons.support_agent_rounded,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            _buildDashboardCard(
              title: '施設予約状況表示',
              description: '本日と翌日の予約内容を確認し、利用者と時間帯をまとめて把握できます。',
              buttonText: '予約状況を見る',
              icon: Icons.insights_rounded,
              onPressed: () => _showTodayAndTomorrowReservations(
                context,
                apartmentId,
                firestore,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 30,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '運用メモ',
                    style: TextStyle(
                      color: Color(0xFF18242D),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'サイドバーから施設カレンダー、掲示板、住人管理、お問い合わせ対応に移動できます。まずはホームで全体件数を見て、優先対応が必要な項目から確認する運用を想定しています。',
                    style: TextStyle(
                      color: Color(0xFF5C6A74),
                      fontSize: 14,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<_OperatorDashboardSummary> _fetchSummary() async {
    final today = DateTime.now();
    final startOfToday = DateTime(today.year, today.month, today.day);
    final startOfTomorrow = startOfToday.add(const Duration(days: 1));

    Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> safeGet(
      Future<QuerySnapshot<Map<String, dynamic>>> future,
    ) async {
      try {
        return (await future).docs;
      } catch (error, stackTrace) {
        debugPrint('Dashboard summary fetch failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return const [];
      }
    }

    final facilityDocs = await safeGet(
      firestore
          .collection('facilities')
          .where('apartment_id', isEqualTo: apartmentId)
          .get(),
    );
    final residentDocs = await safeGet(
      firestore
          .collection('users')
          .where('apartment', isEqualTo: apartmentId)
          .get(),
    );
    final contactDocs = await safeGet(
      firestore
          .collection('contacts')
          .where('apartment', isEqualTo: apartmentId)
          .get(),
    );
    final reservationDocs = await safeGet(
      firestore
          .collection('reservations')
          .where('apartmentId', isEqualTo: apartmentId)
          .get(),
    );

    final residentCount = residentDocs
        .where((doc) => doc.data()['role']?.toString() == 'Resident')
        .length;
    final openContactCount = contactDocs.where((doc) {
      final status = doc.data()['status']?.toString().toLowerCase();
      return status != 'closed';
    }).length;
    final todayReservationCount = reservationDocs.where((doc) {
      final timestamp = doc.data()['date'];
      if (timestamp is! Timestamp) return false;
      final date = timestamp.toDate();
      return !date.isBefore(startOfToday) && date.isBefore(startOfTomorrow);
    }).length;

    return _OperatorDashboardSummary(
      facilityCount: facilityDocs.length,
      residentCount: residentCount,
      openContactCount: openContactCount,
      todayReservationCount: todayReservationCount,
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String description,
    required String buttonText,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9EDF7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: _primary, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF18242D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF5D6B75),
                fontSize: 14,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: const Color(0xFFD9EDF7),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
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

class _OperatorNavItem {
  final String label;
  final String hint;
  final IconData icon;

  const _OperatorNavItem({
    required this.label,
    required this.icon,
    required this.hint,
  });
}

class _OperatorSidebarButton extends StatelessWidget {
  final _OperatorNavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _OperatorSidebarButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = selected
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.transparent;
    final borderColor = selected
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon,
                  color: selected
                      ? const Color(0xFF0C5D78)
                      : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.hint,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _DashboardMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 24,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFD9EDF7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: HomeScreen._primary, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF18242D),
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF24323C),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF6B7882),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorDashboardSummary {
  final int facilityCount;
  final int residentCount;
  final int openContactCount;
  final int todayReservationCount;

  const _OperatorDashboardSummary({
    required this.facilityCount,
    required this.residentCount,
    required this.openContactCount,
    required this.todayReservationCount,
  });
}

void _showTodayAndTomorrowReservations(
  BuildContext context,
  String apartmentId,
  FirebaseFirestore firestore,
) async {
  final today = DateTime.now();
  final tomorrow = today.add(const Duration(days: 1));
  final List<DateTime> targetDates = [today, tomorrow];
  final Map<String, List<Map<String, String>>> reservationsByDate = {};

  for (final date in targetDates) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final snapshot = await firestore
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
        final userDoc = await firestore.collection('users').doc(userId).get();
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
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const FacilityCalendarScreen({
    Key? key,
    required this.apartmentId,
    required this.auth,
    required this.firestore,
    required this.functions,
  }) : super(key: key);

  @override
  _FacilityCalendarScreenState createState() => _FacilityCalendarScreenState();
}

class _FacilityCalendarScreenState extends State<FacilityCalendarScreen> {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);

  List<Map<String, dynamic>> _facilities = [];
  String? _selectedFacilityId;
  Set<String> _unavailableDays = {};
  Map<int, List<String>> _alreadyUnavailableTimesByDay = {};

  Future<void> _fetchUnavailableTimesForDay(int day) async {
    if (_selectedFacilityId == null) return;

    final dateStr =
        '${_selectedMonth.year.toString().padLeft(4, '0')}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

    final docSnapshot = await widget.firestore
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
    final snapshot = await widget.firestore
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

    final querySnapshot = await widget.firestore
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
        final userDoc =
            await widget.firestore.collection('users').doc(userId).get();
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

    final unavailableSnapshot = await widget.firestore
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
                  await widget.firestore
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
                    final batch = widget.firestore.batch();
                    final unavailableRef = widget.firestore
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

    final query = await widget.firestore
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
        final userDoc =
            await widget.firestore.collection('users').doc(userId).get();
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
    final unavailableDoc = await widget.firestore
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
    final docRef = widget.firestore
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
      // (1) 「当日の予約状況ダイアログ」を閉じる
      Navigator.of(context).pop();
      // (2) Firestore から削除 & カレンダー更新
      await _deleteReservation(dateStr, reservation);
      await _fetchReservationsForMonth();
    }
  }

  Future<void> _deleteReservation(
      String dateStr, Map<String, String> reservation) async {
    final ts = Timestamp.fromDate(DateTime.parse(dateStr));
    final query = await widget.firestore
        .collection('reservations')
        .where('facilityId', isEqualTo: _selectedFacilityId)
        .where('date', isEqualTo: ts)
        .get();

    for (final doc in query.docs) {
      final data = doc.data();
      final times = List<String>.from(data['times'] ?? []);
      if (times.isEmpty) continue;
      // final interval = '${times.first} ~ ${_addThirtyMinutes(times.last)}';

      // この行で「キャンセル対象」の予約を特定
      final interval = '${times.first} ~ ${times.last}';
      // ────────── ここから追加 ──────────

      // キャンセルされた予約のユーザーID取得
      final String canceledUserId = data['userId'] as String? ?? '';

      // 予約日時を見やすくフォーマット
      final date = DateTime.parse(dateStr);
      final formattedDate =
          '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
      // 通知ドキュメントを作成
      await widget.firestore.collection('notifications').add({
        'message': '管理人が予約（$formattedDate $interval）をキャンセルしました。',
        'timestamp': Timestamp.now(),
        'read': false,
        'type': 'reservation_cancel', // 任意：種別が必要なら
        'recipients': [canceledUserId], // ← このユーザーだけに
      });

      await doc.reference.delete();
      break;
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
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isUnavailable
                        ? const Color(0xFFFFD6D0)
                        : const Color(0xFFDCE5EB),
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x08000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$day日',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: isUnavailable
                                  ? const Color(0xFFCA4B39)
                                  : const Color(0xFF1B2730),
                            ),
                          ),
                        ),
                        if (dayReservations.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9EDF7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${dayReservations.length}件',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (isUnavailable)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0ED),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '予約不可あり',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCA4B39),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isUnavailable)
                      FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        future: widget.firestore
                            .collection('facilities')
                            .doc(_selectedFacilityId)
                            .collection('unavailable_dates')
                            .doc(dateStr)
                            .get(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState != ConnectionState.done) {
                            return const Text(
                              '予約不可を確認中',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFCA4B39),
                              ),
                            );
                          }
                          if (!snapshot.hasData || !snapshot.data!.exists) {
                            return const SizedBox.shrink();
                          }
                          final data = snapshot.data!.data()!;
                          if (data['allDay'] == true) {
                            return const Text(
                              '1日予約不可',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFFCA4B39),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          } else {
                            final times =
                                List<String>.from(data['unavailableTimes'] ?? []);
                            if (times.isEmpty) {
                              return const Text(
                                '予約不可',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFCA4B39),
                                ),
                              );
                            }
                            final start = times.first;
                            final end = _addThirtyMinutes(times.last);
                            return Text(
                              '$start～$end 予約不可',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFCA4B39),
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          }
                        },
                      ),
                    const SizedBox(height: 6),
                    for (int i = 0; i < displayedIntervals.length; i++)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F8FB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          displayedIntervals[i],
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF30414C),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (dayReservations.length > 3)
                      const Text(
                        'さらに表示...',
                        style: TextStyle(fontSize: 11, color: _primary),
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
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F7FA),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            children: [
              Expanded(
                  child: Center(
                      child: Text('日',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFCA4B39),
                          )))),
              Expanded(
                  child: Center(
                      child: Text('月',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('火',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('水',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('木',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('金',
                          style: TextStyle(fontWeight: FontWeight.w800)))),
              Expanded(
                  child: Center(
                      child: Text('土',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          )))),
            ],
          ),
        ),
        const SizedBox(height: 12),
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

                final user = widget.auth.currentUser;
                if (user == null) return;

                final userDoc = await widget.firestore
                    .collection('users')
                    .doc(user.uid)
                    .get();
                final apartmentId =
                    userDoc.data()?['apartment'] ?? 'unknown_apartment';

                imageUrl = await _uploadImageToStorage();

                await widget.firestore.collection('facilities').add({
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
    final year = _selectedMonth.year;
    final month = _selectedMonth.month.toString().padLeft(2, '0');
    final selectedFacility = _facilities.cast<Map<String, dynamic>?>().firstWhere(
          (facility) => facility?['id'] == _selectedFacilityId,
          orElse: () => null,
        );
    final facilityName = selectedFacility?['name']?.toString() ?? '施設を選択';

    return Container(
      color: _background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 30,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '対象施設',
                            style: TextStyle(
                              color: Color(0xFF6B7882),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_facilities.isEmpty)
                            const Text(
                              '施設を読み込み中...',
                              style: TextStyle(
                                color: Color(0xFF18242D),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F8FB),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFDCE5EB),
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedFacilityId,
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: _primary,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF18242D),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  items: _facilities.map((facility) {
                                    return DropdownMenuItem<String>(
                                      value: facility['id'],
                                      child:
                                          Text(facility['name'] ?? '名称不明'),
                                    );
                                  }).toList(),
                                  onChanged: _onFacilityChanged,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _CalendarActionButton(
                              label: '新規施設追加',
                              icon: Icons.add_business_rounded,
                              onPressed: _addNewFacility,
                            ),
                            const SizedBox(width: 8),
                            _CalendarActionButton(
                              label: '施設削除',
                              icon: Icons.delete_outline_rounded,
                              onPressed: _deleteFacility,
                            ),
                            const SizedBox(width: 8),
                            _CalendarActionButton(
                              label: '予約不可設定',
                              icon: Icons.event_busy_rounded,
                              onPressed: _editCalendar,
                            ),
                            const SizedBox(width: 8),
                            _CalendarActionButton(
                              label: '予定のエクスポート',
                              icon: Icons.file_download_outlined,
                              onPressed: _exportSchedule,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F8FB),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: _previousMonth,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  '$year年 $month月',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF18242D),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  '日付セルをクリックすると予約内容と予約不可設定を確認できます。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _textMuted,
                                  ),
                                ),
                              ],
                            ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: _nextMonth,
                          color: _primary,
                        ),
                      ),
                    ],
                  ),
                ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: _buildCalendar(),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _CalendarActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        foregroundColor: const Color(0xFF0C5D78),
        backgroundColor: const Color(0xFFD9EDF7),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------
   掲示板画面
---------------------------------------------------------------- */
class BulletinBoardScreen extends StatefulWidget {
  final String apartmentId;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const BulletinBoardScreen(
      {Key? key,
      required this.apartmentId,
      required this.firestore,
      required this.functions})
      : super(key: key);

  @override
  State<BulletinBoardScreen> createState() => _BulletinBoardScreenState();
}

class _BulletinBoardScreenState extends State<BulletinBoardScreen> {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  late final FirebaseFirestore firestore;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    firestore = widget.firestore;
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final snapshot = await firestore
        .collection('bulletin_posts')
        .where('apartmentId', isEqualTo: widget.apartmentId)
        .orderBy('createdAt', descending: true)
        .get();

    final postList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
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

  // --- _showCreatePostDialog() の冒頭にもガードを追加 ---
  void _showCreatePostDialog() {
    // 既に100件以上なら警告だけ出して戻る
    if (_posts.length >= 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('投稿は最大100件までです')),
      );
      return;
    }

    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    PlatformFile? selectedPdfFile;
    String? selectedPdfName;
    bool isPdfTooLarge = false;

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
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                        withData: true,
                      );
                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.first;
                        setModalState(() {
                          selectedPdfFile = file;
                          selectedPdfName = file.name;
                          isPdfTooLarge = file.size > 2 * 1024 * 1024; // 2MB超え
                        });
                      }
                    },
                    icon: const Icon(
                        Icons.picture_as_pdf), // or Icons.upload_file
                    label: Text(
                      (selectedPdfName == null || selectedPdfName!.isEmpty)
                          ? '詳細PDFアップロード'
                          : 'PDFを再選択（$selectedPdfName）',
                    ),
                  ),
                  if (selectedPdfName != null) ...[
                    Text('ファイル名：$selectedPdfName'),
                    if (isPdfTooLarge)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text(
                          '⚠️ PDFファイルは最大2MBまでです',
                          style: TextStyle(color: Colors.red),
                        ),
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
                // サイズ超過時は null にして無効化
                onPressed: isPdfTooLarge
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        final body = bodyController.text.trim();
                        if (title.isEmpty || body.isEmpty) return;

                        String? pdfUrl;
                        if (selectedPdfFile?.bytes != null) {
                          final storageRef = FirebaseStorage.instance
                              .ref()
                              .child('bulletins/${selectedPdfFile!.name}');
                          await storageRef.putData(
                            selectedPdfFile!.bytes!,
                            SettableMetadata(contentType: 'application/pdf'),
                          );
                          pdfUrl = await storageRef.getDownloadURL();
                        }

                        // ① 掲示板データを追加
                        await widget.firestore
                            .collection('bulletin_posts')
                            .add({
                          'title': title,
                          'body': body,
                          'pdfUrl': pdfUrl,
                          'apartmentId': widget.apartmentId,
                          'createdAt': Timestamp.now(),
                        });

                        // ② 管理人投稿の通知を全住人に送信
                        await widget.firestore.collection('notifications').add({
                          'message': '管理人が「$title」を掲示板に投稿しました。',
                          'timestamp': Timestamp.now(),
                          'read': false,
                          'type': 'broadcast',
                          'recipients': ['all'],
                        });

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('投稿が完了しました')),
                        );

                        await widget.functions
                            .httpsCallable('sendBulletinNotification')
                            .call({'title': title});

                        _fetchPosts();
                      },
                child: const Text('作成'),
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
    final hasPdf = post['pdfUrl'] != null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showPostDetailDialog(context, post),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE1F4FA),
                              Color(0xFFCDEAF4),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: _primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post['title'],
                              style: const TextStyle(
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w900,
                                color: _textStrong,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              formatted,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: hasPdf
                              ? const Color(0xFFF3FBFE)
                              : const Color(0xFFF4F6F8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          hasPdf ? 'PDF添付あり' : '本文のみ',
                          style: TextStyle(
                            color: hasPdf ? _primary : _textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    post['body'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF42515C),
                      fontSize: 15,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FA),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              size: 16,
                              color: _primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'クリックで詳細を表示',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: _primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showPostDetailDialog(BuildContext context, Map<String, dynamic> post) {
    showDialog(
      context: context,
      // builder のパラメータを dialogContext に変更！
      builder: (BuildContext dialogContext) => AlertDialog(
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
                        const SnackBar(content: Text('PDFを開けませんでした')));
                  }
                },
                child: const Text('PDFを表示'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              // ダイアログを閉じるのは dialogContext
              Navigator.of(dialogContext).pop();
              _showEditPostDialog(context, post);
            },
            child: const Text('編集'),
          ),
          TextButton(
            onPressed: () async {
              // まずダイアログだけ閉じる
              Navigator.of(dialogContext).pop();

              // 投稿を削除
              await widget.firestore
                  .collection('bulletin_posts')
                  .doc(post['id'])
                  .delete();

              // スナックバーは親の context で
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('投稿を削除しました')),
              );

              // リストを再読み込み
              _fetchPosts();
            },
            child: const Text('削除', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  void _showEditPostDialog(
      BuildContext parentContext, Map<String, dynamic> post) {
    final titleController = TextEditingController(text: post['title']);
    final bodyController = TextEditingController(text: post['body']);
    PlatformFile? selectedPdfFile;
    String? selectedPdfName;
    String? originalPdfUrl = post['pdfUrl'];
    bool isPdfTooLarge = false; // ← 追加

    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext sbContext, StateSetter setModalState) {
            return AlertDialog(
              title: const Text('掲示板を編集'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'タイトル'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bodyController,
                      decoration: const InputDecoration(labelText: '本文'),
                      maxLines: 5,
                    ),
                    const SizedBox(height: 16),
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
                            setModalState(() {
                              selectedPdfFile = file;
                              selectedPdfName = file.name;
                              isPdfTooLarge = file.size > 2 * 1024 * 1024;
                            });
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            SnackBar(content: Text('PDF選択に失敗しました: $e')),
                          );
                        }
                      },
                      child: const Text('PDFを再アップロード'),
                    ),
                    if (selectedPdfName != null) ...[
                      Text('ファイル名：$selectedPdfName'),
                      if (isPdfTooLarge)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠️ PDFファイルは最大2MBまでです',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ] else if (originalPdfUrl != null) ...[
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('現在のPDFが登録されています'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('キャンセル'),
                ),
                ElevatedButton(
                  // サイズ超過時は null にして無効化
                  onPressed: isPdfTooLarge
                      ? null
                      : () async {
                          final updatedTitle = titleController.text.trim();
                          final updatedBody = bodyController.text.trim();
                          if (updatedTitle.isEmpty || updatedBody.isEmpty)
                            return;

                          String? updatedPdfUrl = originalPdfUrl;
                          if (selectedPdfFile?.bytes != null) {
                            final storageRef = FirebaseStorage.instance
                                .ref()
                                .child('bulletins/${selectedPdfFile!.name}');
                            await storageRef.putData(
                              selectedPdfFile!.bytes!,
                              SettableMetadata(contentType: 'application/pdf'),
                            );
                            updatedPdfUrl = await storageRef.getDownloadURL();
                          }

                          await widget.firestore
                              .collection('bulletin_posts')
                              .doc(post['id'])
                              .update({
                            'title': updatedTitle,
                            'body': updatedBody,
                            'pdfUrl': updatedPdfUrl,
                          });

                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('投稿を更新しました')),
                          );
                          _fetchPosts();
                        },
                  child: const Text('更新'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- build() 内の該当部分 ---
  @override
  Widget build(BuildContext context) {
    final pdfCount = _posts.where((post) => post['pdfUrl'] != null).length;
    final latestPostDate = _posts.isEmpty
        ? '未投稿'
        : DateFormat('yyyy/MM/dd').format(
            (_posts.first['createdAt'] as Timestamp).toDate(),
          );

    return Container(
      color: _background,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFE7F5FB),
                        Colors.white,
                        Color(0xFFF4FBFE),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primary.withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 980;
                      final infoColumn = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x14004D64),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'NOTICE BOARD',
                              style: TextStyle(
                                color: _primary,
                                fontSize: 12,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '掲示板の投稿と\n周知状況をまとめて管理します。',
                            style: TextStyle(
                              color: _textStrong,
                              fontSize: 34,
                              height: 1.12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            '住民向けのお知らせを一覧で確認し、PDF添付の有無や最新投稿日をひと目で把握できます。重要な案内は新規作成からすぐに追加してください。',
                            style: TextStyle(
                              color: Color(0xFF5A6973),
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.tonalIcon(
                            onPressed:
                                _posts.length >= 100 ? null : _showCreatePostDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(
                              _posts.length >= 100
                                  ? '投稿上限に到達しています'
                                  : '新規掲示板を作成',
                            ),
                            style: FilledButton.styleFrom(
                              foregroundColor: _primary,
                              backgroundColor: const Color(0xFFD9EDF7),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ],
                      );

                      final summaryPanel = Container(
                        width: compact ? double.infinity : 280,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0x140C5D78),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '運用サマリー',
                              style: TextStyle(
                                color: _textStrong,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildOverviewRow(
                              label: '投稿数',
                              value: '${_posts.length}/100',
                            ),
                            const SizedBox(height: 14),
                            _buildOverviewRow(
                              label: 'PDF添付',
                              value: '$pdfCount件',
                            ),
                            const SizedBox(height: 14),
                            _buildOverviewRow(
                              label: '最新投稿日',
                              value: latestPostDate,
                            ),
                          ],
                        ),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            infoColumn,
                            const SizedBox(height: 22),
                            summaryPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: infoColumn),
                          const SizedBox(width: 24),
                          summaryPanel,
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                if (_posts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 40,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 30,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.forum_rounded,
                          size: 52,
                          color: _primary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'まだ掲示はありません',
                          style: TextStyle(
                            color: _textStrong,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '管理からお知らせを投稿すると、ここに一覧表示されます。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ..._posts.map(_buildPostCard),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/* ----------------------------------------------------------------
   アカウント管理画面（サイドバーが消えない修正版）
---------------------------------------------------------------- */
class AccountScreen extends StatelessWidget {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  final String apartmentId;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const AccountScreen({
    Key? key,
    required this.apartmentId,
    required this.auth,
    required this.firestore,
    required this.functions,
  }) : super(key: key);

  // 変更ポイント①: Stream で常時購読（自動反映）
  Stream<List<Map<String, dynamic>>> _residentStream() {
    return firestore
        .collection('users')
        .where('apartment', isEqualTo: apartmentId)
        .where('role', isEqualTo: 'Resident')
        .snapshots()
        .map((qs) => qs.docs.map((d) => {...d.data(), 'id': d.id}).toList());
  }

  /// 単体作成（既存機能、pushReplacement を削除）
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
                  // 可能なら Cloud Functions 側で作成
                  try {
                    final callable =
                        functions.httpsCallable('createResidentAccount');
                    await callable.call(<String, dynamic>{
                      'email':
                          '${roomNumberController.text.trim()}@example.com',
                      'password': passwordController.text.trim(),
                      'roomNumber': roomNumberController.text.trim(),
                      'name': roomNumberController.text.trim(),
                      'role': 'Resident',
                      'apartment': apartmentId,
                    });
                  } on FirebaseFunctionsException {
                    // Fallback（推奨は Functions）
                    final userCredential =
                        await auth.createUserWithEmailAndPassword(
                      email: '${roomNumberController.text.trim()}@example.com',
                      password: passwordController.text.trim(),
                    );
                    await firestore
                        .collection('users')
                        .doc(userCredential.user!.uid)
                        .set({
                      'name': roomNumberController.text.trim(),
                      'email':
                          '${roomNumberController.text.trim()}@example.com',
                      'roomNumber': roomNumberController.text.trim(),
                      'role': 'Resident',
                      'apartment': apartmentId,
                    });
                  }

                  if (context.mounted) {
                    Navigator.pop(context); // ダイアログを閉じるだけ
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('住人アカウントを作成しました。')),
                    );
                  }
                  // リストは StreamBuilder が自動更新
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('エラー: $e')),
                    );
                  }
                }
              },
              child: const Text('作成ボタン'),
            ),
          ],
        );
      },
    );
  }

  /// 一括作成（CSV）— ダイアログから実行（pushReplacement を削除）
  Future<void> _bulkCreateResidents(BuildContext context) async {
    PlatformFile? pickedFile;
    List<int>? pickedBytes;
    String? pickedName;
    bool working = false;

    await showDialog(
      context: context,
      barrierDismissible: !working,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          Future<void> pickCsv() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['csv'],
              withData: true,
            );
            if (result == null || result.files.isEmpty) return;
            final file = result.files.first;
            setState(() {
              pickedFile = file;
              pickedBytes = file.bytes;
              pickedName = file.name;
            });
          }

          Future<void> runCreate() async {
            if (pickedBytes == null || working) return;
            setState(() => working = true);

            try {
              final contentUtf8 =
                  utf8.decode(pickedBytes!, allowMalformed: true);

              final rows = const CsvToListConverter(
                eol: '\n',
                shouldParseNumbers: false,
              ).convert(contentUtf8);

              if (rows.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CSVが空です。')),
                );
                setState(() => working = false);
                return;
              }

              final headers = rows.first
                  .map((e) =>
                      e.toString().trim().toLowerCase().replaceAll(' ', ''))
                  .toList();

              final idxRoom = headers.indexWhere(
                  (h) => h == 'roomnumber' || h == 'room' || h == '部屋番号');
              final idxPass =
                  headers.indexWhere((h) => h == 'password' || h == 'パスワード');

              if (idxRoom == -1 || idxPass == -1) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'CSVヘッダーが見つかりません。（必要: room number / password）\n検出: ${headers.join(', ')}',
                    ),
                  ),
                );
                setState(() => working = false);
                return;
              }

              final residents = <Map<String, dynamic>>[];
              for (int i = 1; i < rows.length; i++) {
                final row = rows[i];
                if (row.length <= idxRoom || row.length <= idxPass) continue;

                final roomNumber = row[idxRoom].toString().trim();
                final password = row[idxPass].toString().trim();
                if (roomNumber.isEmpty || password.isEmpty) continue;

                residents.add({
                  'roomNumber': roomNumber,
                  'password': password,
                });
              }

              if (residents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('有効な行がありませんでした。')),
                );
                setState(() => working = false);
                return;
              }

              final callable = functions.httpsCallable('bulkCreateResidents');
              final resp = await callable.call(<String, dynamic>{
                'apartment': apartmentId,
                'residents': residents,
                'defaultEmailDomain': 'example.com',
              });

              if (ctx.mounted) Navigator.of(ctx).pop(); // ダイアログを閉じる

              final data = resp.data as Map<String, dynamic>;
              final successCount = data['successCount'] ?? 0;
              final failureCount = data['failureCount'] ?? 0;
              final List<dynamic> results = data['results'] ?? [];
              final errors =
                  results.where((r) => r['success'] == false).toList();

              if (errors.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '一括追加が完了しました。成功: $successCount / ${residents.length}')),
                  );
                }
              } else {
                if (context.mounted) {
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('一部失敗しました'),
                      content: SizedBox(
                        width: 520,
                        child: SingleChildScrollView(
                          child: Text([
                            '成功: $successCount / ${residents.length}',
                            '失敗: $failureCount',
                            '--- 失敗詳細 ---',
                            ...errors.map((e) =>
                                '行${(e['index'] as int) + 2} (${(e['roomNumber'] ?? '-').toString()}) : ${e['error']}')
                          ].join('\n')),
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
              }
              // リストは StreamBuilder が自動更新
            } catch (e) {
              setState(() => working = false);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('一括追加エラー: $e')),
                );
              }
            }
          }

          return AlertDialog(
            title: const Text('一括入居者追加'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      pickedName == null
                          ? 'CSVファイル：未選択'
                          : 'CSVファイル：$pickedName',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: working ? null : pickCsv,
                      icon: const Icon(Icons.upload_file),
                      label: Text(pickedName == null
                          ? 'CSVアップロード'
                          : 'CSVを再選択（$pickedName）'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '※ ヘッダーに「room number」「password」を含むCSVを指定してください。',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: working ? null : () => Navigator.pop(ctx),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: (pickedBytes != null && !working) ? runCreate : null,
                child: working
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('作成'),
              ),
            ],
          );
        });
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
                final uid = resident['id'] as String;
                try {
                  final callable = functions.httpsCallable('deleteUserAccount');
                  final result =
                      await callable.call(<String, dynamic>{'uid': uid});

                  if (result.data['success'] == true) {
                    if (context.mounted) {
                      Navigator.pop(context); // ダイアログを閉じるだけ
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('住人アカウントを削除しました。')),
                      );
                    }
                    // リストは StreamBuilder が自動更新
                  }
                } on FirebaseFunctionsException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('削除に失敗しました: ${e.message}')),
                    );
                  }
                }
              },
              child: const Text('削除ボタン'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        foregroundColor: foregroundColor,
        backgroundColor: backgroundColor,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }

  Widget _buildResidentCard(
    BuildContext context,
    Map<String, dynamic> resident,
  ) {
    final name = resident['name']?.toString().trim();
    final roomNumber = resident['roomNumber']?.toString().trim();
    final email = resident['email']?.toString().trim();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _showResidentDialog(context, resident),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name == null || name.isEmpty ? '名前未設定' : name,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F7FA),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '部屋番号 ${roomNumber == null || roomNumber.isEmpty ? '未設定' : roomNumber}',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (email != null && email.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F8FA),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  email,
                                  style: const TextStyle(
                                    color: _textMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _background,
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _residentStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('読み込みに失敗しました: ${snapshot.error}'));
          }

          final residents = snapshot.data ?? [];
          final roomCount = residents
              .map((resident) => resident['roomNumber']?.toString() ?? '')
              .where((room) => room.isNotEmpty)
              .toSet()
              .length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFE7F5FB),
                      Colors.white,
                      Color(0xFFF4FBFE),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withValues(alpha: 0.10),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 1020;
                    final infoColumn = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x14004D64),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'RESIDENT ACCOUNTS',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 12,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          '住人アカウントを\n一覧管理できます。',
                          style: TextStyle(
                            color: _textStrong,
                            fontSize: 34,
                            height: 1.12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          '登録済みアカウントの確認、個別作成、CSV一括追加をこの画面から行えます。部屋番号ごとの管理状況もひと目で把握できます。',
                          style: TextStyle(
                            color: Color(0xFF5A6973),
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildActionButton(
                              onPressed: () => _createResidentAccount(context),
                              icon: Icons.person_add_alt_1_rounded,
                              label: '新規住人アカウント作成',
                              backgroundColor: const Color(0xFFD9EDF7),
                              foregroundColor: _primary,
                            ),
                            _buildActionButton(
                              onPressed: () => _bulkCreateResidents(context),
                              icon: Icons.upload_file_rounded,
                              label: '一括入居者追加',
                              backgroundColor: const Color(0xFFEAF3F7),
                              foregroundColor: _primary,
                            ),
                          ],
                        ),
                      ],
                    );

                    final summaryPanel = Container(
                      width: compact ? double.infinity : 300,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0x140C5D78),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '運用サマリー',
                            style: TextStyle(
                              color: _textStrong,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _buildSummaryRow(
                            label: '登録アカウント',
                            value: '${residents.length}件',
                          ),
                          const SizedBox(height: 14),
                          _buildSummaryRow(
                            label: '登録部屋数',
                            value: '$roomCount室',
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'カードをクリックすると削除を含む詳細操作を開けます。',
                            style: TextStyle(
                              color: _textMuted,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    );

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          infoColumn,
                          const SizedBox(height: 22),
                          summaryPanel,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: infoColumn),
                        const SizedBox(width: 24),
                        summaryPanel,
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              if (residents.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 40,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 30,
                        offset: Offset(0, 16),
                      ),
                    ],
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 52,
                        color: _primary,
                      ),
                      SizedBox(height: 16),
                      Text(
                        '住人情報が見つかりませんでした',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '新規作成またはCSVアップロードで住人アカウントを追加してください。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...residents.map((resident) => _buildResidentCard(context, resident)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// 管理者用 お問い合わせ管理画面（クローズ時は回答不可）
// ---------------------------------------------------------------
class ContactScreen extends StatefulWidget {
  final String apartmentId;
  final FirebaseFirestore firestore;

  const ContactScreen({
    Key? key,
    required this.apartmentId,
    required this.firestore,
  }) : super(key: key);

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen>
    with SingleTickerProviderStateMixin {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseQuery = widget.firestore
        .collection('contacts')
        .where('apartment', isEqualTo: widget.apartmentId);

    return Container(
      color: _background,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(34),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE7F5FB),
                    Colors.white,
                    Color(0xFFF4FBFE),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 980;
                  final infoColumn = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ContactHeroBadge(),
                      SizedBox(height: 18),
                      Text(
                        'お問い合わせの確認と\n回答対応をまとめて行えます。',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 34,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        '未回答チケットを優先的に確認し、全件履歴も同じ画面で追跡できます。カードを選ぶと、そのまま返信やクローズ操作へ進めます。',
                        style: TextStyle(
                          color: Color(0xFF5A6973),
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ],
                  );

                  final summaryPanel = Container(
                    width: compact ? double.infinity : 300,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: const Color(0x140C5D78),
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '画面の見方',
                          style: TextStyle(
                            color: _textStrong,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 18),
                        _ContactSummaryRow(
                          label: '未回答',
                          value: '優先確認',
                        ),
                        SizedBox(height: 14),
                        _ContactSummaryRow(
                          label: '全件',
                          value: '履歴確認',
                        ),
                        SizedBox(height: 14),
                        Text(
                          'タブで対象を切り替えて、カードから詳細ダイアログを開きます。',
                          style: TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        infoColumn,
                        const SizedBox(height: 22),
                        summaryPanel,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: infoColumn),
                      const SizedBox(width: 24),
                      summaryPanel,
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 30,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    TabBar(
                      controller: _tab,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: const Color(0xFFD9EDF7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      labelColor: _primary,
                      unselectedLabelColor: _textMuted,
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      tabs: const [
                        Tab(text: '未回答'),
                        Tab(text: '全件'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tab,
                        children: [
                          _ContactListView(
                            query: baseQuery
                                .where('status', isEqualTo: 'open')
                                .orderBy('updatedAt', descending: true),
                            firestore: widget.firestore,
                          ),
                          _ContactListView(
                            query: baseQuery.orderBy(
                              'updatedAt',
                              descending: true,
                            ),
                            firestore: widget.firestore,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactListView extends StatelessWidget {
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  final Query<Map<String, dynamic>> query;
  final FirebaseFirestore firestore;

  const _ContactListView({
    Key? key,
    required this.query,
    required this.firestore,
  }) : super(key: key);

  String _fmtTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Widget _statusChip(String status) {
    Color c;
    String label;
    switch (status) {
      case 'open':
        c = Colors.orange;
        label = '未回答';
        break;
      case 'answered':
        c = Colors.green;
        label = '回答済み';
        break;
      case 'closed':
        c = Colors.grey;
        label = 'クローズ';
        break;
      default:
        c = Colors.blueGrey;
        label = status;
    }
    return Chip(
      label: Text(label),
      backgroundColor: c.withOpacity(0.15),
      side: BorderSide.none,
      labelStyle: TextStyle(
        color: c,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildTicketCard(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data()!;
    final subject = (data['subject'] as String?) ?? '(件名なし)';
    final name = (data['name'] as String?) ?? '';
    final createdAt = _fmtTs(data['createdAt'] as Timestamp?);
    final updatedAt = _fmtTs(data['updatedAt'] as Timestamp?);
    final status = (data['status'] as String?) ?? 'open';
    final category = (data['category'] as String?) ?? '';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () => _openTicketDialog(context, doc),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: _primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _statusChip(status),
                            if (category.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F7FA),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: _primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (name.isNotEmpty)
                          Text(
                            'ユーザー: $name',
                            style: const TextStyle(
                              color: _textMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          '作成: $createdAt',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '更新: $updatedAt',
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Firestore エラー表示（インデックス作成リンクが含まれていれば開ける）
  Widget _errorView(Object error) {
    String msg = '読み込みに失敗しました。';
    String? indexUrl;

    if (error is FirebaseException) {
      msg = error.message ?? msg;
      final m = RegExp(r'https://console\.firebase\.google\.com/[^\s]+')
          .firstMatch(msg);
      if (m != null) indexUrl = m.group(0);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (indexUrl != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: const Text('インデックスを作成'),
                onPressed: () async {
                  final uri = Uri.parse(indexUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTicketDialog(
    BuildContext context,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data()!;
    final subject = (data['subject'] as String?) ?? '(件名なし)';
    final userName = (data['name'] as String?) ?? '';
    final userEmail = (data['email'] as String?) ?? '';
    final message = (data['message'] as String?) ?? '';
    final category = (data['category'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'open';
    final isClosed = status == 'closed'; // ★ クローズ判定
    final userId = (data['userId'] as String?) ?? '';

    final replyCtl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: Text(subject),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _statusChip(status),
                      if (category.isNotEmpty) Chip(label: Text(category)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (userName.isNotEmpty) Text('ユーザー: $userName'),
                  if (userEmail.isNotEmpty) Text('メール: $userEmail'),
                  const SizedBox(height: 12),
                  const Text('質問内容',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(message),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('やり取り',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),

                  // スレッド
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: firestore
                        .collection('contacts')
                        .doc(doc.id)
                        .collection('replies')
                        .orderBy('createdAt')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) return _errorView(snap.error!);
                      final replies = snap.data?.docs ?? [];
                      if (replies.isEmpty) return const Text('まだ回答はありません。');

                      return Column(
                        children: replies.map((r) {
                          final d = r.data();
                          final sender = (d['sender'] as String?) ?? 'admin';
                          final text = (d['text'] as String?) ?? '';
                          final ts = _fmtTs(d['createdAt'] as Timestamp?);
                          final isAdmin = sender == 'admin';
                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isAdmin
                                  ? Colors.purple.withOpacity(0.06)
                                  : Colors.blueGrey.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isAdmin ? '管理者' : 'ユーザー',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 2),
                                Text(text),
                                const SizedBox(height: 4),
                                Text(ts,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  // ★ クローズ時は入力不可＆グレーアウト
                  TextField(
                    controller: replyCtl,
                    maxLines: 4,
                    enabled: !isClosed,
                    readOnly: isClosed,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '回答を入力',
                      hintText:
                          isClosed ? 'クローズ済みのため入力できません' : 'ユーザーに送る回答内容を入力',
                      filled: isClosed,
                      fillColor: isClosed ? Colors.grey.shade200 : null,
                    ),
                  ),
                  if (isClosed)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'このお問い合わせはクローズされています。追記できません。',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            // 閉じる
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),

            // クローズ（確認付き）
            OutlinedButton.icon(
              icon: const Icon(Icons.lock),
              label: const Text('クローズ'),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: ctx,
                  builder: (confirmCtx) => AlertDialog(
                    title: const Text('お問い合わせをクローズしますか？'),
                    content: const Text(
                      'クローズ後はユーザー側でこのチケットに返信できなくなります（閲覧は可能）。',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(confirmCtx, false),
                        child: const Text('キャンセル'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(confirmCtx, true),
                        child: const Text('クローズする'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;

                try {
                  await doc.reference.update({
                    'status': 'closed',
                    'updatedAt': FieldValue.serverTimestamp(),
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('クローズしました')),
                    );
                  }
                } on FirebaseException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('クローズに失敗しました: ${e.message ?? e.code}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('クローズに失敗しました: $e')),
                    );
                  }
                }
              },
            ),

            // 回答送信（クローズ時は無効）
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('回答送信'),
              onPressed: isClosed
                  ? null
                  : () async {
                      final text = replyCtl.text.trim();
                      if (text.isEmpty) return;

                      try {
                        // 1) スレッド追加
                        await firestore
                            .collection('contacts')
                            .doc(doc.id)
                            .collection('replies')
                            .add({
                          'sender': 'admin',
                          'text': text,
                          'createdAt': FieldValue.serverTimestamp(),
                        });

                        // 2) 親更新（回答済み）
                        await doc.reference.update({
                          'status': 'answered',
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        // 3) 通知
                        final subject =
                            (doc.data()?['subject'] as String?) ?? '(件名なし)';
                        final userId = (doc.data()?['userId'] as String?) ?? '';
                        await firestore.collection('notifications').add({
                          'message': 'お問い合わせ「$subject」に管理者から回答が届きました。',
                          'timestamp': Timestamp.now(),
                          'read': false,
                          'type': 'contact_reply',
                          'recipients': [userId],
                        });

                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('回答を送信しました')),
                          );
                        }
                      } on FirebaseException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                                  Text('送信に失敗しました: ${e.message ?? e.code}'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('送信に失敗しました: $e')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return _errorView(snap.error!);
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_read_rounded,
                  size: 52,
                  color: _primary,
                ),
                SizedBox(height: 16),
                Text(
                  '該当するお問い合わせはありません。',
                  style: TextStyle(
                    color: _textStrong,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, i) {
            return _buildTicketCard(context, docs[i]);
          },
        );
      },
    );
  }
}

class _ContactHeroBadge extends StatelessWidget {
  const _ContactHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x14004D64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'CONTACT SUPPORT',
        style: TextStyle(
          color: _ContactScreenState._primary,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactSummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _ContactSummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: _ContactScreenState._textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: _ContactScreenState._textStrong,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroBadge extends StatelessWidget {
  const _ProfileHeroBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x14004D64),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'ACCOUNT SETTINGS',
        style: TextStyle(
          color: ProfileScreen._primary,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  static const _background = Color(0xFFF6F8FB);
  static const _primary = Color(0xFF0C5D78);
  static const _textMuted = Color(0xFF60707A);
  static const _textStrong = Color(0xFF18242D);

  final FirebaseAuth auth;
  const ProfileScreen({Key? key, required this.auth}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインが必要です'));
    }

    return Container(
      color: _background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(34),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE7F5FB),
                  Colors.white,
                  Color(0xFFF4FBFE),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 980;
                final infoColumn = const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeroBadge(),
                    SizedBox(height: 18),
                    Text(
                      'アカウント設定を\n安全に管理できます。',
                      style: TextStyle(
                        color: _textStrong,
                        fontSize: 34,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      'ログイン中の管理アカウント情報を確認し、メールアドレスやパスワードの変更をこの画面から実行できます。',
                      style: TextStyle(
                        color: Color(0xFF5A6973),
                        fontSize: 14,
                        height: 1.7,
                      ),
                    ),
                  ],
                );

                final accountPanel = Container(
                  width: compact ? double.infinity : 320,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0x140C5D78),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '現在のアカウント',
                        style: TextStyle(
                          color: _textStrong,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F7FA),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alternate_email_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                user.email ?? 'メール未設定',
                                style: const TextStyle(
                                  color: _textStrong,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoColumn,
                      const SizedBox(height: 22),
                      accountPanel,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: infoColumn),
                    const SizedBox(width: 24),
                    accountPanel,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x12000000),
                  blurRadius: 30,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'セキュリティ設定',
                  style: TextStyle(
                    color: _textStrong,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '認証情報の変更は再認証を伴います。安全な環境で操作してください。',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 22),
                _buildProfileActionCard(
                  icon: Icons.edit_rounded,
                  title: 'メールアドレスを変更',
                  subtitle: 'ログインに使用するメールアドレスを更新します。',
                  onTap: () => _changeEmail(context, user),
                ),
                const SizedBox(height: 16),
                _buildProfileActionCard(
                  icon: Icons.lock_rounded,
                  title: 'パスワードを変更',
                  subtitle: '管理アカウントのパスワードを再設定します。',
                  onTap: () => _changePassword(context, user),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: Material(
          color: const Color(0xFFFDFEFF),
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFE1F4FA),
                          Color(0xFFCDEAF4),
                        ],
                      ),
                    ),
                    child: Icon(icon, color: _primary, size: 28),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _textStrong,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                            height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeEmail(BuildContext context, User user) async {
    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('メール変更'),
        content: TextField(
          controller: pwdCtl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '現在のパスワード'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('次へ')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: pwdCtl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('新しいメールアドレス'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: newCtl,
                decoration: const InputDecoration(labelText: '新メール')),
            TextField(
                controller: confirmCtl,
                decoration: const InputDecoration(labelText: '確認用')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtl.text.trim() != confirmCtl.text.trim()) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('メールが一致しません')));
                return;
              }
              try {
                await user.verifyBeforeUpdateEmail(newCtl.text.trim());
                Navigator.pop(ctx2);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('確認メールを送信しました')));
              } catch (e) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('エラー: $e')));
              }
            },
            child: const Text('送信'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, User user) async {
    final pwdCtl = TextEditingController();
    final newCtl = TextEditingController();
    final confirmCtl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('パスワード変更'),
        content: TextField(
          controller: pwdCtl,
          obscureText: true,
          decoration: const InputDecoration(labelText: '現在のパスワード'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('次へ')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: pwdCtl.text.trim(),
      );
      await user.reauthenticateWithCredential(cred);
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('認証失敗')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (ctx2) => AlertDialog(
        title: const Text('新しいパスワード'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: newCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '新パスワード')),
            TextField(
                controller: confirmCtl,
                obscureText: true,
                decoration: const InputDecoration(labelText: '確認用パスワード')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx2), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              if (newCtl.text.trim() != confirmCtl.text.trim()) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードが一致しません')));
                return;
              }
              try {
                await user.updatePassword(newCtl.text.trim());
                Navigator.pop(ctx2);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('パスワードを更新しました')));
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
}
