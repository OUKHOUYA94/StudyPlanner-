import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import '../messages/chat_page.dart';
import 'subject_detail_page.dart';
import 'subjects_providers.dart';

class SubjectsPage extends ConsumerWidget {
  const SubjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isTeacher = appUser?.isTeacher ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mati\u00e8res'),
      ),
      body: subjectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (subjects) {
          if (subjects.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.menu_book_outlined,
                      size: 64,
                      color: AppColors.textSecondary.withAlpha(120)),
                  const SizedBox(height: 16),
                  Text(
                    isTeacher
                        ? 'Aucune mati\u00e8re assign\u00e9e.'
                        : 'Aucune mati\u00e8re trouv\u00e9e.',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          // Dev warning if student class doesn't have exactly 6 subjects
          final showDevWarning = kDebugMode &&
              !isTeacher &&
              subjects.length != 6;

          // Group by classId for display
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final s in subjects) {
            final classId = s['classId'] as String;
            grouped.putIfAbsent(classId, () => []).add(s);
          }

          final classIds = grouped.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (showDevWarning)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.secondary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.secondary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Attention : ${subjects.length} mati\u00e8re(s) au lieu de 6.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              for (final classId in classIds) ...[
                if (isTeacher || classIds.length > 1) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      'Classe : $classId',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
                ...grouped[classId]!.map((subject) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SubjectCard(subject: subject),
                    )),
                if (classId != classIds.last) const SizedBox(height: 8),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;

  const _SubjectCard({required this.subject});

  @override
  Widget build(BuildContext context) {
    final name = subject['name'] as String;
    final classId = subject['classId'] as String;
    final subjectId = subject['subjectId'] as String;
    final teacherName = subject['teacherName'] as String? ?? '';
    final active = subject['active'] as bool;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SubjectDetailPage(
              classId: classId,
              subjectId: subjectId,
              subjectName: name,
              teacherName: teacherName,
            ),
          ),
        );
      },
      child: Container(
        decoration: AppCardStyles.cardDecoration,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withAlpha(25)
                    : AppColors.textSecondary.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: active ? AppColors.primary : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: active
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                  ),
                  if (teacherName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      teacherName,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      title: name,
                      classId: classId,
                      subjectId: subjectId,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chat_bubble_outline,
                  size: 20,
                  color: AppColors.primary.withAlpha(180),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
