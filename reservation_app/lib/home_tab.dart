import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:reservation_app/bulletin_tab.dart';
import 'package:reservation_app/pdf_view_screen.dart';
import 'package:intl/intl.dart';

class HomeTab extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  const HomeTab({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ?? FirebaseFunctions.instance,
        super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  User? _currentUser;
  Map<String, dynamic>? _userInfo;
  String? _apartmentName;
  late StreamSubscription<User?> _authSubscription;
  List<Map<String, dynamic>> _latestPosts = [];

  @override
  void initState() {
    super.initState();
    _authSubscription = widget.auth.authStateChanges().listen((user) {
      if (user != null) {
        setState(() => _currentUser = user);
        _fetchUserData();
      }
    });
    _currentUser = widget.auth.currentUser;
    _fetchUserData();
    _fetchLatestPosts();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (_currentUser == null) return;
    try {
      final userDoc = await widget.firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .get();
      final userData = userDoc.data();
      if (userData != null && mounted) setState(() => _userInfo = userData);

      final apartmentId = userData?['apartment'];
      if (apartmentId != null) {
        final apartmentDoc = await widget.firestore
            .collection('apartments')
            .doc(apartmentId)
            .get();
        if (mounted)
          setState(() =>
              _apartmentName = apartmentDoc.data()?['name'] ?? '不明なマンション');
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('ユーザー情報の取得に失敗しました。再読み込みしてください。'),
                  backgroundColor: Colors.red),
            );
          }
        });
      }
    }
  }

  Future<void> _fetchLatestPosts() async {
    try {
      final snapshot = await widget.firestore
          .collection('bulletin_posts')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final posts = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'title': data['title'] ?? '無題',
          'body': data['body'] ?? '',
          'pdfUrl': data['pdfUrl'],
          'createdAt': data['createdAt'],
        };
      }).toList();

      if (mounted) setState(() => _latestPosts = posts);
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('掲示の取得に失敗しました。通信環境を確認してください。'),
                  backgroundColor: Colors.red),
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userInfo == null || _apartmentName == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('マイページ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.auth.signOut();
              if (mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('マンション名: $_apartmentName',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('部屋番号: ${_userInfo?['roomNumber'] ?? '不明'}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('氏名: ${_userInfo?['name'] ?? '不明'}',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 24),
            ..._latestPosts.map(_buildLatestPostCard).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestPostCard(Map<String, dynamic> post) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate =
        date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '不明';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: ListTile(
        title: Text(post['title']),
        subtitle: Text('投稿日: $formattedDate'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPostDetailDialog(post),
      ),
    );
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post['title']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post['body']),
              const SizedBox(height: 16),
              if (post['pdfUrl'] != null)
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(url: post['pdfUrl']),
                      ),
                    );
                  },
                  child: const Text('PDFを表示'),
                ),
            ],
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
