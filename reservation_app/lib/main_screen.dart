import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_tab.dart'; // ホームタブの画面
import 'reservation_tab.dart'; // 施設予約タブの画面
import 'bulletin_tab.dart'; // 掲示板タブの画面
import 'notification_tab.dart'; // ← 通知タブの画面をインポート

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // 順番は「施設予約」「掲示板」「通知」「マイページ」
  final List<Widget> _screens = [
    const ReservationTab(),
    const BulletinTab(),
    const HomeTab(),
    const NotificationTab(),
  ];

  @override
  Widget build(BuildContext context) {
    // 毎回最新のユーザーIDを取得
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: _screens[_currentIndex],
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
            // StreamBuilderで未読件数を監視してバッジ表示
            icon: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('read', isEqualTo: false)
                  .where(
                'recipients',
                arrayContainsAny: ['all', userId],
              ).snapshots(),
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
