import 'package:flutter/material.dart';
import 'home_tab.dart'; // ホームタブの画面
import 'reservation_tab.dart'; // 施設予約タブの画面
import 'bulletin_tab.dart'; // 掲示板タブの画面

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const ReservationTab(), // 施設予約画面
    const BulletinTab(), // 掲示板画面
    const HomeTab(), // ホーム画面
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '施設予約',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: '掲示板',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'マイページ',
          ),
        ],
      ),
    );
  }
}
