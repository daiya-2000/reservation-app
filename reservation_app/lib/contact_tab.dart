import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ContactTab extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const ContactTab({
    Key? key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : auth = auth ?? FirebaseAuth.instance,
        firestore = firestore ?? FirebaseFirestore.instance,
        super(key: key);

  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('お問い合わせ'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'お問い合わせ'),
              Tab(text: '回答'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _ContactFormView(
              auth: widget.auth,
              firestore: widget.firestore,
            ),
            _ContactAnswersView(
              auth: widget.auth,
              firestore: widget.firestore,
            ),
          ],
        ),
      ),
    );
  }
}

/// タブ1: お問い合わせ送信
class _ContactFormView extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const _ContactFormView({
    Key? key,
    required this.auth,
    required this.firestore,
  }) : super(key: key);

  @override
  State<_ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends State<_ContactFormView> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = '施設利用について';
  bool _sending = false;

  String? _prefilledEmail;
  String? _prefilledName;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final user = widget.auth.currentUser;
    if (user == null) return;
    try {
      final doc =
          await widget.firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      setState(() {
        _prefilledEmail = (data?['email'] as String?) ?? user.email;
        _prefilledName = (data?['name'] as String?) ?? '';
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = widget.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン後にお問い合わせをご利用ください。')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      String? apartmentId;
      try {
        final u =
            await widget.firestore.collection('users').doc(user.uid).get();
        apartmentId = u.data()?['apartment']?.toString();
      } catch (_) {}

      await widget.firestore.collection('contacts').add({
        'userId': user.uid,
        'apartment': apartmentId,
        'email': _prefilledEmail ?? user.email,
        'name': _prefilledName ?? '',
        'category': _category,
        'subject': _subjectCtrl.text.trim(),
        'message': _messageCtrl.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信しました。順次対応いたします。')),
        );
        _subjectCtrl.clear();
        _messageCtrl.clear();
        setState(() => _category = '施設利用について');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_prefilledName != null && _prefilledName!.isNotEmpty)
              Text('お名前: $_prefilledName'),
            if (_prefilledEmail != null && _prefilledEmail!.isNotEmpty)
              Text('メール: $_prefilledEmail'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'カテゴリ',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: '施設利用について', child: Text('施設利用について')),
                DropdownMenuItem(value: 'アプリのバグ報告', child: Text('アプリのバグ報告')),
                DropdownMenuItem(value: 'その他', child: Text('その他')),
              ],
              onChanged: (v) => setState(() => _category = v ?? '施設利用について'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: '件名',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '件名を入力してください' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: '内容',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? '内容を入力してください' : null,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: const Text('送信する'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '※ 送信内容は管理画面から確認・対応されます。',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// タブ2: 自分の問い合わせと回答の一覧
class _ContactAnswersView extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const _ContactAnswersView({
    Key? key,
    required this.auth,
    required this.firestore,
  }) : super(key: key);

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = auth.currentUser;
    if (user == null) {
      return const Center(child: Text('ログイン後に表示されます。'));
    }

    final q = firestore
        .collection('contacts')
        .where('userId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('お問い合わせ履歴はありません。'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            return _TicketTile(
              contactId: docs[i].id,
              data: data,
              firestore: firestore,
              currentUser: user,
            );
          },
        );
      },
    );
  }
}

/// 1件分のチケットカード（スレッド表示＋ユーザー返信＋クローズ）
class _TicketTile extends StatefulWidget {
  final String contactId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final User currentUser;

  const _TicketTile({
    Key? key,
    required this.contactId,
    required this.data,
    required this.firestore,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<_TicketTile> createState() => _TicketTileState();
}

class _TicketTileState extends State<_TicketTile> {
  final _replyCtl = TextEditingController();
  bool _sending = false;

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '';
    final d = ts.toDate();
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _replyCtl.dispose();
    super.dispose();
  }

  Future<void> _sendReply(String text) async {
    if (text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.firestore
          .collection('contacts')
          .doc(widget.contactId)
          .collection('replies')
          .add({
        'sender': 'user',
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await widget.firestore
          .collection('contacts')
          .doc(widget.contactId)
          .update({
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('返信を送信しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('送信に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmAndClose() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お問い合わせをクローズしますか？'),
        content: const Text(
          'クローズ後はこのチケットに返信できなくなります（閲覧は可能）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('クローズする'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    setState(() => _sending = true);
    try {
      await widget.firestore
          .collection('contacts')
          .doc(widget.contactId)
          .update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クローズしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('クローズに失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openReplySheet() {
    _replyCtl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('返信を入力',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _replyCtl,
                    minLines: 1,
                    maxLines: 6,
                    autofocus: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '管理者への追記・返信を入力',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _sending
                            ? null
                            : () {
                                _replyCtl.clear();
                                Navigator.of(ctx).pop();
                              },
                        child: const Text('閉じる'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed:
                            _sending ? null : () => _sendReply(_replyCtl.text),
                        icon: _sending
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                        label: const Text('送信'),
                      ),
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

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final subject = (data['subject'] as String?) ?? '(件名なし)';
    final category = (data['category'] as String?) ?? '';
    final status = (data['status'] as String?) ?? 'open';
    final createdAt = _formatTs(data['createdAt'] as Timestamp?);
    final updatedAt = _formatTs(data['updatedAt'] as Timestamp?);
    final firstMessage = (data['message'] as String?) ?? '';
    final isClosed = status == 'closed';

    return Card(
      elevation: 0.5,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        title:
            Text(subject, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('$category / $status\n作成: $createdAt　更新: $updatedAt'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          const Text('あなたの質問', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(firstMessage),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const Text('管理者の回答', style: TextStyle(fontWeight: FontWeight.bold)),

          // スレッド表示
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.firestore
                .collection('contacts')
                .doc(widget.contactId)
                .collection('replies')
                .orderBy('createdAt')
                .snapshots(),
            builder: (context, rs) {
              if (rs.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: LinearProgressIndicator(),
                );
              }
              final replies = rs.data?.docs ?? [];
              if (replies.isEmpty) {
                return const Text('まだ回答はありません。');
              }
              return Column(
                children: replies.map((r) {
                  final d = r.data();
                  final sender = (d['sender'] as String?) ?? 'admin';
                  final text = (d['text'] as String?) ?? '';
                  final ts = _formatTs(d['createdAt'] as Timestamp?);
                  final isAdmin = sender == 'admin';
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isAdmin ? Colors.grey.shade100 : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            isAdmin ? Icons.admin_panel_settings : Icons.person,
                            size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(isAdmin ? '管理者' : 'あなた',
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
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ★ クローズ + 返信する（クローズ時は両方無効）
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: (isClosed || _sending) ? null : _confirmAndClose,
                icon: const Icon(Icons.lock),
                label: const Text('クローズ'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: (isClosed || _sending) ? null : _openReplySheet,
                icon: const Icon(Icons.reply),
                label: const Text('返信する'),
              ),
            ],
          ),

          if (isClosed)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'このお問い合わせはクローズされています。追記する場合は新規でお問い合わせください。',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
