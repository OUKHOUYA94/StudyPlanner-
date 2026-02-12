import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import '../schedule/schedule_providers.dart';
import 'assessment_form_page.dart';
import 'assessments_providers.dart';

class AssessmentsPage extends ConsumerWidget {
  const AssessmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isTeacher = appUser?.isTeacher ?? false;

    return DefaultTabController(
      length: 2,
      child: Stack(
        children: [
          Column(
            children: [
              Container(
                color: AppColors.cardSurface,
                child: const TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    Tab(text: 'Aujourd\'hui'),
                    Tab(text: 'Cette semaine'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _TodayTab(),
                    _WeekTab(),
                  ],
                ),
              ),
            ],
          ),
          if (isTeacher)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                onPressed: () => _openCreateForm(context, ref),
                child: const Icon(Icons.add),
              ),
            ),
        ],
      ),
    );
  }

  void _openCreateForm(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AssessmentFormPage()),
    );
    if (result == true) {
      ref.invalidate(todayAssessmentsProvider);
      ref.invalidate(weekAssessmentsProvider);
    }
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAssessments = ref.watch(todayAssessmentsProvider);
    final isTeacher = ref.watch(appUserProvider).valueOrNull?.isTeacher ?? false;

    return todayAssessments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (assessments) {
        if (assessments.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: AppColors.textSecondary.withAlpha(120)),
                const SizedBox(height: 16),
                Text(
                  'Aucun examen aujourd\'hui',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: assessments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _AssessmentCard(
            assessment: assessments[index],
            isTeacher: isTeacher,
          ),
        );
      },
    );
  }
}

class _WeekTab extends ConsumerWidget {
  const _WeekTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekAssessments = ref.watch(weekAssessmentsProvider);
    final isTeacher = ref.watch(appUserProvider).valueOrNull?.isTeacher ?? false;

    return weekAssessments.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (grouped) {
        if (grouped.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_outlined,
                    size: 64, color: AppColors.textSecondary.withAlpha(120)),
                const SizedBox(height: 16),
                Text(
                  'Aucun examen cette semaine',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        final sortedDays = grouped.keys.toList()..sort();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];
            final items = grouped[day]!;
            final dow = day.weekday;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${dayName(dow)} ${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.primary),
                  ),
                ),
                ...items.map(
                    (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AssessmentCard(
                            assessment: a,
                            isTeacher: isTeacher,
                          ),
                        )),
              ],
            );
          },
        );
      },
    );
  }
}

class _AssessmentCard extends ConsumerWidget {
  final Map<String, dynamic> assessment;
  final bool isTeacher;

  const _AssessmentCard({
    required this.assessment,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = assessment['title'] as String;
    final type = assessmentTypeLabel(assessment['type'] as String);
    final classId = assessment['classId'] as String;
    final subject = assessment['subjectId'] as String;
    final status = assessment['status'] as String;
    final dt = assessment['dateTime'] as DateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    final isCanceled = status == 'canceled';

    return Container(
      decoration: AppCardStyles.cardDecoration,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isCanceled
                      ? AppColors.textSecondary.withAlpha(25)
                      : AppColors.secondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isCanceled
                        ? AppColors.textSecondary
                        : AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration:
                                isCanceled ? TextDecoration.lineThrough : null,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$type \u2022 $subject \u2022 $classId',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isCanceled)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel(status),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ),
            ],
          ),
          // Teacher actions row
          if (isTeacher && !isCanceled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _editAssessment(context, ref),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _cancelAssessment(context, ref),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Annuler'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _editAssessment(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AssessmentFormPage(assessment: assessment),
      ),
    );
    if (result == true) {
      ref.invalidate(todayAssessmentsProvider);
      ref.invalidate(weekAssessmentsProvider);
    }
  }

  void _cancelAssessment(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler l\'examen'),
        content:
            const Text('\u00cates-vous s\u00fbr de vouloir annuler cet examen ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await callCancelAssessment(
        classId: assessment['classId'] as String,
        assessmentId: assessment['assessmentId'] as String,
      );
      ref.invalidate(todayAssessmentsProvider);
      ref.invalidate(weekAssessmentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Examen annul\u00e9 avec succ\u00e8s.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        String message = e.toString();
        if (message.contains(']')) {
          message = message.substring(message.lastIndexOf(']') + 1).trim();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
