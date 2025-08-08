import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationTab extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const NotificationTab({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        super(key: key);

  @override
  State<NotificationTab> createState() => _NotificationTabState();
}

class _NotificationTabState extends State<NotificationTab> {
  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;
    if (user == null) {
      return const Center(child: Text('ログインしてください'));
    }
    final userId = user.uid;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.firestore
          .collection('notifications')
          .where('recipients', arrayContainsAny: [userId, 'all'])
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              '通知の取得中にエラーが発生しました:\n${snap.error}',
              textAlign: TextAlign.center,
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('通知はありません'));
        }

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final msg = data['message'] as String? ?? '';
            final ts =
                (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
            final read = data['read'] as bool? ?? false;

            return ListTile(
              leading: Icon(
                read ? Icons.notifications_none : Icons.notifications_active,
                color: read ? Colors.grey : Colors.red,
              ),
              title: Text(msg),
              subtitle: Text(
                "${ts.year}/${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')} "
                "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}",
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                docs[i].reference.update({'read': true});
              },
            );
          },
        );
      },
    );
  }
}
