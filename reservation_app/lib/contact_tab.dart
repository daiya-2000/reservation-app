import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ContactTab extends StatefulWidget {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuth get auth => _auth ?? FirebaseAuth.instance;
  FirebaseFirestore get firestore => _firestore ?? FirebaseFirestore.instance;

  const ContactTab({
    super.key,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth,
        _firestore = firestore;

  @override
  State<ContactTab> createState() => _ContactTabState();
}

class _ContactTabState extends State<ContactTab> {
  static const _background = Color(0xFFF7F9FB);
  static const _primary = Color(0xFF004D64);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _ContactHeader(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: TabBar(
                    labelColor: _primary,
                    unselectedLabelColor: const Color(0xFF6B7B84),
                    labelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    indicator: BoxDecoration(
                      color: const Color(0x14004D64),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(6),
                    tabs: const [
                      Tab(text: 'お問い合わせ'),
                      Tab(text: '回答'),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactHeader extends StatelessWidget {
  const _ContactHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
            'お問い合わせ',
            style: TextStyle(
              color: Color(0xFF004D64),
              fontSize: 30,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '施設利用やアプリの不具合、各種相談を送信できます。返信内容はこの画面の「回答」タブから確認できます。',
            style: TextStyle(
              color: Color(0xFF52616B),
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactFormView extends StatefulWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const _ContactFormView({
    required this.auth,
    required this.firestore,
  });

  @override
  State<_ContactFormView> createState() => _ContactFormViewState();
}

class _ContactFormViewState extends State<_ContactFormView> {
  static const _primary = Color(0xFF004D64);
  static const _textMuted = Color(0xFF5E6C76);

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
      final doc = await widget.firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      if (!mounted) return;
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
        final u = await widget.firestore.collection('users').doc(user.uid).get();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送信しました。順次対応いたします。')),
      );
      _subjectCtrl.clear();
      _messageCtrl.clear();
      setState(() => _category = '施設利用について');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
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
      top: false,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.mail_outline_rounded, color: _primary),
                      SizedBox(width: 8),
                      Text(
                        '送信フォーム',
                        style: TextStyle(
                          color: Color(0xFF172126),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_prefilledName != null && _prefilledName!.isNotEmpty)
                    _InfoRow(label: 'お名前', value: _prefilledName!),
                  if (_prefilledEmail != null && _prefilledEmail!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _InfoRow(label: 'メール', value: _prefilledEmail!),
                    ),
                  const SizedBox(height: 18),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: _inputDecoration('カテゴリ'),
                    items: const [
                      DropdownMenuItem(value: '施設利用について', child: Text('施設利用について')),
                      DropdownMenuItem(value: 'アプリのバグ報告', child: Text('アプリのバグ報告')),
                      DropdownMenuItem(value: 'その他', child: Text('その他')),
                    ],
                    onChanged: (value) =>
                        setState(() => _category = value ?? '施設利用について'),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _subjectCtrl,
                    decoration: _inputDecoration('件名'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '件名を入力してください' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _messageCtrl,
                    minLines: 6,
                    maxLines: 12,
                    decoration: _inputDecoration('内容', alignLabelWithHint: true),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '内容を入力してください' : null,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('送信する'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '※ 送信内容は管理画面から確認・対応されます。',
                    style: TextStyle(
                      color: _textMuted,
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
    );
  }

  InputDecoration _inputDecoration(String label, {bool alignLabelWithHint = false}) {
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: const Color(0xFFF8FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
    );
  }
}

class _ContactAnswersView extends StatelessWidget {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const _ContactAnswersView({
    required this.auth,
    required this.firestore,
  });

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
          return const _AnswersEmptyState();
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final data = docs[index].data();
            return _TicketTile(
              contactId: docs[index].id,
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

class _TicketTile extends StatefulWidget {
  final String contactId;
  final Map<String, dynamic> data;
  final FirebaseFirestore firestore;
  final User currentUser;

  const _TicketTile({
    required this.contactId,
    required this.data,
    required this.firestore,
    required this.currentUser,
  });

  @override
  State<_TicketTile> createState() => _TicketTileState();
}

class _TicketTileState extends State<_TicketTile> {
  static const _primary = Color(0xFF004D64);
  static const _textMuted = Color(0xFF5E6C76);

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

      await widget.firestore.collection('contacts').doc(widget.contactId).update({
        'status': 'open',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('返信を送信しました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('送信に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmAndClose() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('お問い合わせをクローズしますか？'),
        content: const Text('クローズ後はこのチケットに返信できなくなります。'),
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
      await widget.firestore.collection('contacts').doc(widget.contactId).update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('クローズしました')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('クローズに失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openReplySheet() {
    _replyCtl.clear();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom + 12, left: 12, right: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                  const Text(
                    '返信を入力',
                    style: TextStyle(
                      color: Color(0xFF172126),
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _replyCtl,
                    minLines: 3,
                    maxLines: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFB),
                      hintText: '管理者への追記・返信を入力',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color(0xFFE1E7EB)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _sending
                              ? null
                              : () {
                                  _replyCtl.clear();
                                  Navigator.of(ctx).pop();
                                },
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text('閉じる'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed:
                              _sending ? null : () => _sendReply(_replyCtl.text),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(50),
                            backgroundColor: _primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          icon: _sending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: const Text('送信'),
                        ),
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

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          subject,
          style: const TextStyle(
            color: Color(0xFF182227),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    label: category,
                    color: const Color(0xFFE8F7FF),
                    textColor: _primary,
                  ),
                  _StatusChip(
                    label: status == 'closed' ? 'closed' : 'open',
                    color: isClosed
                        ? const Color(0xFFF3F6F8)
                        : const Color(0xFFEFF7EA),
                    textColor:
                        isClosed ? const Color(0xFF5E6C76) : const Color(0xFF245C2A),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '作成: $createdAt\n更新: $updatedAt',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'あなたの質問',
                  style: TextStyle(
                    color: Color(0xFF172126),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  firstMessage,
                  style: const TextStyle(
                    color: Color(0xFF33424C),
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '管理者の回答',
            style: TextStyle(
              color: Color(0xFF172126),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
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
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFB),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'まだ回答はありません。',
                    style: TextStyle(
                      color: _textMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
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
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? const Color(0xFFEFF7EA)
                          : const Color(0xFFF8FAFB),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isAdmin
                                ? const Color(0xFFD7EFD8)
                                : const Color(0xFFE2ECF2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isAdmin
                                ? Icons.admin_panel_settings_outlined
                                : Icons.person_outline_rounded,
                            size: 18,
                            color: isAdmin
                                ? const Color(0xFF245C2A)
                                : const Color(0xFF4E6472),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdmin ? '管理者' : 'あなた',
                                style: const TextStyle(
                                  color: Color(0xFF172126),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                text,
                                style: const TextStyle(
                                  color: Color(0xFF33424C),
                                  fontSize: 14,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                ts,
                                style: const TextStyle(
                                  color: _textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (isClosed || _sending) ? null : _confirmAndClose,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('クローズ'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: (isClosed || _sending) ? null : _openReplySheet,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.reply_rounded),
                  label: const Text('返信する'),
                ),
              ),
            ],
          ),
          if (isClosed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'このお問い合わせはクローズされています。追記する場合は新規でお問い合わせください。',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5E6C76),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF182227),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _StatusChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _AnswersEmptyState extends StatelessWidget {
  const _AnswersEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_email_read_outlined,
                size: 56, color: Color(0xFF7A8B95)),
            SizedBox(height: 16),
            Text(
              'お問い合わせ履歴はありません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1F2A30),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '送信したお問い合わせと管理者からの返信はここに表示されます。',
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
