import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:reservation_app/pdf_view_screen.dart';

class BulletinTab extends StatefulWidget {
  const BulletinTab({Key? key}) : super(key: key);

  @override
  State<BulletinTab> createState() => _BulletinTabState();
}

class _BulletinTabState extends State<BulletinTab> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bulletin_posts')
        .orderBy('createdAt', descending: true)
        .get();

    final postList = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'title': data['title'] ?? '無題',
        'body': data['body'] ?? '',
        'pdfUrl': data['pdfUrl'],
        'createdAt': data['createdAt'],
      };
    }).toList();

    setState(() {
      _posts = postList;
      _isLoading = false;
    });
  }

  void _showPostDetailDialog(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post['title']),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
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

  Widget _buildPostCard(Map<String, dynamic> post) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(post['title']),
        subtitle: Text(
          post['body'],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPostDetailDialog(post),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('掲示板'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? const Center(child: Text('掲示板はまだありません'))
              : ListView.builder(
                  itemCount: _posts.length,
                  itemBuilder: (context, index) {
                    return _buildPostCard(_posts[index]);
                  },
                ),
    );
  }
}
