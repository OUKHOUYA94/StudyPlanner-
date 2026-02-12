import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import '../subjects/subjects_providers.dart';
import 'chat_page.dart';
import 'messages_providers.dart';

/// Subject-based color palette (same as schedule).
const _subjectColors = [
  Color(0xFF4A90D9),
  Color(0xFFE8724A),
  Color(0xFF50B88E),
  Color(0xFF9B59B6),
  Color(0xFFE74C8B),
  Color(0xFFF2994A),
  Color(0xFF2EC4B6),
];

Color _colorForSubject(String subjectId) {
  return _subjectColors[subjectId.hashCode.abs() % _subjectColors.length];
}

class MessagesPage extends ConsumerWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final classIdsAsync = ref.watch(chatClassIdsProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    if (appUser == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTeacher = appUser.role == 'teacher';

    return classIdsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (classIds) {
        if (classIds.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline,
                        size: 40, color: AppColors.primary.withAlpha(120)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Aucune classe assign\u00e9e',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous n\u2019avez pas encore de conversations.',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            for (final classId in classIds) ...[
              // ── Class header (if multiple classes) ──
              if (classIds.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, top: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school_outlined,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Text(
                              classId,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: AppColors.textSecondary.withAlpha(30),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Class chat (students only) ──
              if (!isTeacher) ...[
                _ClassChatCard(
                  classId: classId,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        title: 'Chat $classId',
                        classId: classId,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Subject chats header ──
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Discussions par mati\u00e8re',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

              // ── Subject chat cards ──
              subjectsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text('Erreur : $e',
                      style: TextStyle(color: AppColors.error)),
                ),
                data: (allSubjects) {
                  final classSubjects = allSubjects
                      .where((s) => s['classId'] == classId)
                      .toList();

                  if (classSubjects.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withAlpha(8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.textSecondary.withAlpha(25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18,
                                color: AppColors.textSecondary.withAlpha(150)),
                            const SizedBox(width: 10),
                            Text(
                              'Aucune mati\u00e8re disponible.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: classSubjects
                        .map((subject) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _SubjectChatCard(
                                subjectId: subject['subjectId'] as String,
                                subjectName: subject['name'] as String,
                                teacherName:
                                    subject['teacherName'] as String,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatPage(
                                      title: subject['name'] as String,
                                      classId: classId,
                                      subjectId:
                                          subject['subjectId'] as String,
                                    ),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  );
                },
              ),

              if (classId != classIds.last) const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

/// Prominent gradient card for the class-wide chat.
class _ClassChatCard extends StatelessWidget {
  final String classId;
  final VoidCallback onTap;

  const _ClassChatCard({required this.classId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withAlpha(190)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(40),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.groups_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chat de classe',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Discussion g\u00e9n\u00e9rale \u2022 $classId',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withAlpha(190),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card for a subject-specific chat with colored accent.
class _SubjectChatCard extends StatelessWidget {
  final String subjectId;
  final String subjectName;
  final String teacherName;
  final VoidCallback onTap;

  const _SubjectChatCard({
    required this.subjectId,
    required this.subjectName,
    required this.teacherName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _colorForSubject(subjectId);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textSecondary.withAlpha(25)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Colored accent bar
            Container(
              width: 5,
              height: 64,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Subject icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.menu_book_rounded, color: color, size: 20),
            ),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subjectName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (teacherName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 3),
                          Text(
                            teacherName,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Arrow
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withAlpha(120), size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
