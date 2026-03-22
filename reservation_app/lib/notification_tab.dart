import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationTab extends StatefulWidget {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  const NotificationTab({
    super.key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  @override
  State<NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<NotificationTab> {
  static const _pageBackground = Color(0xFFF7F9FB);

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }

    return Container(
      color: _pageBackground,
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.firestore
              .collection('notifications')
              .where('recipients', arrayContainsAny: [user.uid, 'all'])
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snap) {
            if (snap.hasError) {
              return _NotificationError(message: '${snap.error}');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data?.docs ?? [];
            final unreadCount = docs
                .where((doc) => !(doc.data()['read'] as bool? ?? false))
                .length;

            if (docs.isEmpty) {
              return const _EmptyNotificationState();
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
              children: [
                _NotificationHero(
                  unreadCount: unreadCount,
                  totalCount: docs.length,
                ),
                const SizedBox(height: 24),
                ...docs.map((doc) {
                  final data = doc.data();
                  final read = data['read'] as bool? ?? false;
                  final message = data['message'] as String? ?? '';
                  final timestamp =
                      (data['timestamp'] as Timestamp?)?.toDate() ??
                          DateTime.now();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _NotificationCard(
                      message: message,
                      timestamp: timestamp,
                      read: read,
                      onTap: () async {
                        if (!read) {
                          await doc.reference.update({'read': true});
                        }
                      },
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NotificationHero extends StatelessWidget {
  final int unreadCount;
  final int totalCount;

  const _NotificationHero({
    required this.unreadCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D5D78).withValues(alpha: 0.10),
            blurRadius: 36,
            offset: const Offset(0, 18),
          ),
        ],
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE7F5FB),
            Colors.white,
            Color(0xFFF5FBFE),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '通知',
            style: TextStyle(
              color: Color(0xFF004D64),
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '掲示板投稿やお問い合わせ回答など、住民向けの最新通知を一覧で確認できます。',
            style: TextStyle(
              color: Color(0xFF52616B),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroChip(
                icon: Icons.mark_chat_unread_rounded,
                label: '未読 $unreadCount 件',
              ),
              _HeroChip(
                icon: Icons.notifications_active_outlined,
                label: '通知 $totalCount 件',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String message;
  final DateTime timestamp;
  final bool read;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.message,
    required this.timestamp,
    required this.read,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBorder = read ? const Color(0xFFE2EAF0) : const Color(0xFFB8DDED);
    final cardBackground =
        read ? Colors.white : const Color(0xFFF7FCFF);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF113146).withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: read
                      ? const Color(0xFFF0F4F7)
                      : const Color(0xFFDDF1FA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  read
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_rounded,
                  color: read ? const Color(0xFF8896A2) : const Color(0xFF0D5D78),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: read
                                ? const Color(0xFFF1F4F7)
                                : const Color(0xFFD8ECF6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            read ? '既読' : '未読',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: read
                                  ? const Color(0xFF66737D)
                                  : const Color(0xFF0D5D78),
                            ),
                          ),
                        ),
                        Text(
                          _formatDateTime(timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF73828D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.55,
                        color: Color(0xFF18242D),
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          read ? '確認済み' : 'タップで既読にする',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7A84),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: Color(0xFF6B7A84),
                        ),
                      ],
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

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD8ECF6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF0D5D78)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF254455),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10364C).withValues(alpha: 0.08),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFD8ECF6),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 34,
                  color: Color(0xFF0D5D78),
                ),
              ),
              SizedBox(height: 16),
              Text(
                '通知はまだありません',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18242D),
                ),
              ),
              SizedBox(height: 10),
              Text(
                '新しいお知らせや回答が届くと、ここに一覧で表示されます。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  color: Color(0xFF697883),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationError extends StatelessWidget {
  final String message;

  const _NotificationError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFFFE5E2),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 34,
                  color: Color(0xFFB74634),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '通知を取得できませんでした',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF18242D),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF697883),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime ts) {
  final year = ts.year.toString().padLeft(4, '0');
  final month = ts.month.toString().padLeft(2, '0');
  final day = ts.day.toString().padLeft(2, '0');
  final hour = ts.hour.toString().padLeft(2, '0');
  final minute = ts.minute.toString().padLeft(2, '0');
  return '$year/$month/$day $hour:$minute';
}
