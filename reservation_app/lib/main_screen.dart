import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_tab.dart';
import 'reservation_tab.dart';
import 'bulletin_tab.dart';
import 'notification_tab.dart';

class MainScreen extends StatefulWidget {
  final int initialTabIndex;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  /// 通知バッジ用のstreamをテスト時に差し替え可能にする
  final Stream<QuerySnapshot<Map<String, dynamic>>>? notificationStream;

  const MainScreen({
    Key? key,
    required this.auth,
    required this.firestore,
    required this.functions,
    this.notificationStream,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex;
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.auth.currentUser?.uid ?? '';

    final screens = [
      ReservationTab(auth: widget.auth, firestore: widget.firestore),
      BulletinTab(firestore: widget.firestore),
      HomeTab(
        auth: widget.auth,
        firestore: widget.firestore,
        functions: widget.functions,
      ),
      NotificationTab(auth: widget.auth, firestore: widget.firestore),
    ];

    final notificationStream = widget.notificationStream ??
        widget.firestore
            .collection('notifications')
            .where('read', isEqualTo: false)
            .where('recipients', arrayContainsAny: ['all', userId]).snapshots();

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '施設予約',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: '掲示板',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'マイページ',
          ),
          BottomNavigationBarItem(
            icon: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: notificationStream,
              builder: (context, snapshot) {
                final unread =
                    snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications),
                    if (unread > 0)
                      Positioned(
                        top: -2,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            label: '通知',
          ),
        ],
      ),
    );
  }
}
