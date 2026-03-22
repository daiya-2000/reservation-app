import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:reservation_app/pdf_view_screen.dart';

class BulletinTab extends StatefulWidget {
  final FirebaseFirestore? _firestore;

  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  const BulletinTab({super.key, FirebaseFirestore? firestore})
      : _firestore = firestore;

  @override
  State<BulletinTab> createState() => _BulletinTabState();
}

class _BulletinTabState extends State<BulletinTab> {
  static const _background = Color(0xFFF7F9FB);
  static const _primary = Color(0xFF004D64);
  static const _textMuted = Color(0xFF5E6C76);

  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final snapshot = await widget.firestore
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

      if (!mounted) return;
      setState(() {
        _posts = postList;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('掲示の取得に失敗しました: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('掲示の取得に失敗しました。再度お試しください。'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPostDetailSheet(Map<String, dynamic> post) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate =
        date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '不明';
    final hasPdf = post['pdfUrl'] != null && post['pdfUrl'].toString().isNotEmpty;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
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
            child: SafeArea(
              top: false,
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x14004D64),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'BULLETIN DETAIL',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    post['title']?.toString() ?? '無題',
                    style: const TextStyle(
                      color: Color(0xFF182227),
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          color: Color(0xFF6B7B84), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '投稿日: $formattedDate',
                        style: const TextStyle(
                          color: Color(0xFF6B7B84),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(sheetContext).size.height * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        post['body']?.toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF33424C),
                          fontSize: 15,
                          height: 1.7,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                            side: const BorderSide(color: Color(0xFFE0E6EA)),
                          ),
                          child: const Text('閉じる'),
                        ),
                      ),
                      if (hasPdf) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      PdfViewerScreen(url: post['pdfUrl']),
                                ),
                              );
                            },
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: _primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: const Text('PDFを表示'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final timestamp = post['createdAt'] as Timestamp?;
    final date = timestamp?.toDate();
    final formattedDate =
        date != null ? DateFormat('yyyy/MM/dd HH:mm').format(date) : '不明';
    final body = post['body']?.toString() ?? '';
    final hasPdf = post['pdfUrl'] != null && post['pdfUrl'].toString().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPostDetailSheet(post),
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: index.isEven
                        ? const Color(0xFFE8F7FF)
                        : const Color(0xFFFFF1E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    hasPdf ? Icons.picture_as_pdf_outlined : Icons.campaign_outlined,
                    color: hasPdf ? _primary : const Color(0xFF9A5A1A),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['title']?.toString() ?? '無題',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF182227),
                          fontSize: 22,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textMuted,
                          fontSize: 14,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _MetaChip(
                            icon: Icons.schedule_rounded,
                            label: formattedDate,
                          ),
                          if (hasPdf)
                            const _MetaChip(
                              icon: Icons.attach_file_rounded,
                              label: 'PDFあり',
                              secondary: true,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF42525C),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
                ? const _BulletinEmptyState()
                : CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: _BulletinHero(),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                        sliver: SliverList.separated(
                          itemCount: _posts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 16),
                          itemBuilder: (context, index) =>
                              _buildPostCard(_posts[index], index),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _BulletinHero extends StatelessWidget {
  const _BulletinHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F7FF), Color(0xFFFFFFFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14004D64),
            blurRadius: 28,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '掲示板',
            style: TextStyle(
              color: Color(0xFF004D64),
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'マンションからのお知らせや共有情報を一覧で確認できます。重要な投稿や添付PDFもここからそのまま開けます。',
            style: TextStyle(
              color: Color(0xFF52616B),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.forum_outlined, color: Color(0xFF004D64), size: 18),
              SizedBox(width: 8),
              Text(
                '新着投稿をチェック',
                style: TextStyle(
                  color: Color(0xFF004D64),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool secondary;

  const _MetaChip({
    required this.icon,
    required this.label,
    this.secondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: secondary ? const Color(0xFFF3F6F8) : const Color(0xFFD8ECF7),
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

class _BulletinEmptyState extends StatelessWidget {
  const _BulletinEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 56, color: Color(0xFF7A8B95)),
            SizedBox(height: 16),
            Text(
              '掲示板はまだありません',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2A30),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '新しいお知らせが投稿されると、ここに一覧表示されます。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF5F6D77),
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
