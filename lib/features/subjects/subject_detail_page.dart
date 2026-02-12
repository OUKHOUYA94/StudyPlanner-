import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../messages/chat_page.dart';
import '../schedule/schedule_providers.dart';
import 'subjects_providers.dart';

/// Detail page for a single subject showing teacher info and schedule.
class SubjectDetailPage extends ConsumerWidget {
  final String classId;
  final String subjectId;
  final String subjectName;
  final String teacherName;

  const SubjectDetailPage({
    super.key,
    required this.classId,
    required this.subjectId,
    required this.subjectName,
    required this.teacherName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(
      subjectScheduleProvider((classId: classId, subjectId: subjectId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(subjectName),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Subject info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: AppCardStyles.cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subjectName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Classe : $classId',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  // Teacher info
                  Row(
                    children: [
                      const Icon(Icons.person_outlined,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Enseignant',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      teacherName.isNotEmpty ? teacherName : 'Non assigné',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Schedule section
            Text(
              'Horaires',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            scheduleAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur : $e'),
              data: (slots) {
                if (slots.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: AppCardStyles.cardDecoration,
                    child: Text(
                      'Aucun horaire défini.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return Column(
                  children: slots
                      .map((slot) => _ScheduleSlotCard(slot: slot))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Chat button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        title: subjectName,
                        classId: classId,
                        subjectId: subjectId,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Ouvrir le chat'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleSlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;

  const _ScheduleSlotCard({required this.slot});

  @override
  Widget build(BuildContext context) {
    final dayOfWeek = slot['dayOfWeek'] as int;
    final startMinute = slot['startMinute'] as int;
    final endMinute = slot['endMinute'] as int;
    final room = slot['room'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppCardStyles.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 80,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  formatTime(startMinute),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  formatTime(endMinute),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayName(dayOfWeek),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (room != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.room_outlined,
                          size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        room,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
