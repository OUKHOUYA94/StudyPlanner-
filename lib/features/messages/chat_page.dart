import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import 'messages_providers.dart';

/// Reusable chat thread page.
/// Pass [subjectId] for subject chat; omit for class chat.
class ChatPage extends ConsumerStatefulWidget {
  final String title;
  final String classId;
  final String? subjectId;

  const ChatPage({
    super.key,
    required this.title,
    required this.classId,
    this.subjectId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  bool get _isSubjectChat => widget.subjectId != null;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final appUser = ref.read(appUserProvider).valueOrNull;
    if (appUser == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      if (_isSubjectChat) {
        await sendSubjectChatMessage(
          classId: widget.classId,
          subjectId: widget.subjectId!,
          senderUid: appUser.uid,
          senderName: appUser.fullName,
          senderRole: appUser.role,
          text: text,
        );
      } else {
        await sendClassChatMessage(
          classId: widget.classId,
          senderUid: appUser.uid,
          senderName: appUser.fullName,
          senderRole: appUser.role,
          text: text,
        );
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = _isSubjectChat
        ? ref.watch(subjectChatMessagesProvider(
            (classId: widget.classId, subjectId: widget.subjectId!)))
        : ref.watch(classChatMessagesProvider(widget.classId));

    final currentUid = ref.watch(appUserProvider).valueOrNull?.uid;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isSubjectChat
                    ? Icons.menu_book_rounded
                    : Icons.groups_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isSubjectChat
                        ? 'Discussion mati\u00e8re'
                        : 'Discussion g\u00e9n\u00e9rale',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
        ),
        child: Column(
          children: [
            // Messages list
            Expanded(
              child: messagesAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erreur : $e')),
                data: (messages) {
                  if (messages.isEmpty) {
                    return _EmptyChat(isSubject: _isSubjectChat);
                  }

                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['senderUid'] == currentUid;

                      // Date separator
                      Widget? dateSeparator;
                      if (index == 0 || _isDifferentDay(
                        messages[index - 1]['createdAt'] as Timestamp?,
                        msg['createdAt'] as Timestamp?,
                      )) {
                        dateSeparator = _DateSeparator(
                          timestamp: msg['createdAt'] as Timestamp?,
                        );
                      }

                      // Show sender name only if different from previous
                      final showSender = !isMe && (index == 0 ||
                          messages[index - 1]['senderUid'] != msg['senderUid'] ||
                          _isDifferentDay(
                            messages[index - 1]['createdAt'] as Timestamp?,
                            msg['createdAt'] as Timestamp?,
                          ));

                      return Column(
                        children: [
                          ?dateSeparator,
                          _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            showSender: showSender,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // Input bar
            _ChatInputBar(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  bool _isDifferentDay(Timestamp? a, Timestamp? b) {
    if (a == null || b == null) return true;
    final da = a.toDate();
    final db = b.toDate();
    return da.year != db.year || da.month != db.month || da.day != db.day;
  }
}

// ── Empty state ──────────────────────────────────────────────────────

class _EmptyChat extends StatelessWidget {
  final bool isSubject;
  const _EmptyChat({required this.isSubject});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSubject ? Icons.menu_book_rounded : Icons.forum_rounded,
                size: 42,
                color: AppColors.primary.withAlpha(120),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Aucun message',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Soyez le premier \u00e0 \u00e9crire\ndans cette discussion !',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withAlpha(30),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 18, color: AppColors.primary.withAlpha(150)),
                  const SizedBox(width: 6),
                  Text(
                    '\u00c9crivez ci-dessous',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary.withAlpha(150),
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
}

// ── Date separator ───────────────────────────────────────────────────

const _months = [
  'janvier', 'f\u00e9vrier', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'ao\u00fbt', 'septembre', 'octobre', 'novembre', 'd\u00e9cembre',
];

class _DateSeparator extends StatelessWidget {
  final Timestamp? timestamp;
  const _DateSeparator({required this.timestamp});

  @override
  Widget build(BuildContext context) {
    String label;
    if (timestamp == null) {
      label = 'Maintenant';
    } else {
      final d = timestamp!.toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final msgDay = DateTime(d.year, d.month, d.day);
      final diff = today.difference(msgDay).inDays;

      if (diff == 0) {
        label = "Aujourd'hui";
      } else if (diff == 1) {
        label = 'Hier';
      } else {
        label = '${d.day} ${_months[d.month - 1]}';
        if (d.year != now.year) label += ' ${d.year}';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.textSecondary.withAlpha(30),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withAlpha(12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.textSecondary.withAlpha(30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar color from sender name ────────────────────────────────────

const _avatarColors = [
  Color(0xFF4A90D9),
  Color(0xFFE8724A),
  Color(0xFF50B88E),
  Color(0xFF9B59B6),
  Color(0xFFE74C8B),
  Color(0xFFF2994A),
  Color(0xFF2EC4B6),
  Color(0xFF6C5CE7),
];

Color _avatarColor(String uid) {
  return _avatarColors[uid.hashCode.abs() % _avatarColors.length];
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name.isNotEmpty ? name[0].toUpperCase() : '?';
}

// ── Message bubble ───────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isMe;
  final bool showSender;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showSender,
  });

  @override
  Widget build(BuildContext context) {
    final name = message['senderName'] as String;
    final role = message['senderRole'] as String;
    final text = message['text'] as String;
    final uid = message['senderUid'] as String;
    final ts = message['createdAt'] as Timestamp?;
    final isTeacher = role == 'teacher';

    final time = ts != null
        ? '${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : '';

    if (isMe) {
      return _MyBubble(text: text, time: time);
    }

    final color = _avatarColor(uid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (only on first message of a group)
          if (showSender)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _initials(name),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 34),

          const SizedBox(width: 8),

          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              margin: EdgeInsets.only(top: showSender ? 8 : 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(showSender ? 4 : 16),
                  topRight: const Radius.circular(16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
                border: Border.all(
                  color: AppColors.textSecondary.withAlpha(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(6),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showSender)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                          if (isTeacher) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Enseignant',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      time,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withAlpha(150),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── My message (right-aligned, blue) ─────────────────────────────────

class _MyBubble extends StatelessWidget {
  final String text;
  final String time;
  const _MyBubble({required this.text, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withAlpha(210),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(30),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withAlpha(160),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar ────────────────────────────────────────────────────────

class _ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _ChatInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 12,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.textSecondary.withAlpha(25),
                ),
              ),
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: '\u00c9crire un message...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: sending
                    ? [
                        AppColors.textSecondary.withAlpha(60),
                        AppColors.textSecondary.withAlpha(40),
                      ]
                    : [
                        AppColors.primary,
                        AppColors.primary.withAlpha(200),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: sending
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.primary.withAlpha(40),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: sending ? null : onSend,
                borderRadius: BorderRadius.circular(14),
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
