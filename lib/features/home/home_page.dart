import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../assessments/assessments_providers.dart';
import '../auth/auth_providers.dart';
import '../schedule/schedule_providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appUser = ref.watch(appUserProvider);

    return appUser.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Utilisateur introuvable.'));
        }
        return _DashboardContent(
          userName: user.fullName,
          isTeacher: user.isTeacher,
          userUid: user.uid,
          classId: user.classId,
        );
      },
    );
  }
}

class _DashboardContent extends ConsumerWidget {
  final String userName;
  final bool isTeacher;
  final String userUid;
  final String? classId;

  const _DashboardContent({
    required this.userName,
    required this.isTeacher,
    required this.userUid,
    this.classId,
  });

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bonjour';
    if (hour < 18) return 'Bon apr\u00e8s-midi';
    return 'Bonsoir';
  }

  String _todayDate() {
    final now = DateTime.now();
    const months = [
      '', 'janvier', 'f\u00e9vrier', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'ao\u00fbt', 'septembre', 'octobre', 'novembre', 'd\u00e9cembre',
    ];
    const days = [
      '', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche',
    ];
    return '${days[now.weekday]} ${now.day} ${months[now.month]} ${now.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todaySlots = ref.watch(todaySlotsProvider);
    final upcoming = ref.watch(upcomingAssessmentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting header ──
          _buildGreetingHeader(context),
          const SizedBox(height: 20),

          // ── Quick stats ──
          todaySlots.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (slots) {
              final mySlots = _filterSlots(slots);
              return upcoming.when(
                loading: () => _buildStatsRow(context, mySlots.length, 0),
                error: (_, _) => _buildStatsRow(context, mySlots.length, 0),
                data: (exams) =>
                    _buildStatsRow(context, mySlots.length, exams.length),
              );
            },
          ),
          const SizedBox(height: 20),

          // ── Current / Next session highlight ──
          todaySlots.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (slots) {
              final mySlots = _filterSlots(slots);
              final highlight = _findCurrentOrNext(mySlots);
              if (highlight == null) return const SizedBox.shrink();
              return Column(
                children: [
                  _buildHighlightCard(context, highlight),
                  const SizedBox(height: 20),
                ],
              );
            },
          ),

          // ── Today's schedule ──
          _buildSectionHeader(context, 'Programme du jour', Icons.schedule_outlined),
          const SizedBox(height: 10),
          todaySlots.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (slots) {
              final mySlots = _filterSlots(slots);
              if (mySlots.isEmpty) {
                return _buildEmptyCard(
                  context,
                  Icons.event_busy_outlined,
                  'Aucune s\u00e9ance aujourd\'hui',
                  'Profitez de votre journ\u00e9e libre !',
                );
              }
              return _buildScheduleTimeline(context, mySlots);
            },
          ),
          const SizedBox(height: 20),

          // ── Upcoming assessments (year) ──
          _buildSectionHeader(context, 'Examens programm\u00e9s', Icons.assignment_outlined),
          const SizedBox(height: 10),
          upcoming.when(
            loading: () => const _LoadingCard(),
            error: (e, _) => _ErrorCard(message: '$e'),
            data: (assessments) {
              if (assessments.isEmpty) {
                return _buildEmptyCard(
                  context,
                  Icons.check_circle_outline,
                  'Aucun examen programm\u00e9',
                  'Pas d\'examens \u00e0 venir pour le moment.',
                );
              }
              return Column(
                children: assessments
                    .map((a) => _buildAssessmentCard(context, a))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  /// Filter slots: teacher sees only their own, student sees all.
  List<Map<String, dynamic>> _filterSlots(List<Map<String, dynamic>> slots) {
    if (!isTeacher) return slots;
    return slots.where((s) => s['teacherUid'] == userUid).toList();
  }

  /// Find current or next upcoming session based on time.
  Map<String, dynamic>? _findCurrentOrNext(List<Map<String, dynamic>> slots) {
    if (slots.isEmpty) return null;
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    // Find current session (nowMinutes between start and end)
    for (final s in slots) {
      final start = s['startMinute'] as int;
      final end = s['endMinute'] as int;
      if (nowMinutes >= start && nowMinutes < end) {
        return {...s, '_status': 'current'};
      }
    }

    // Find next upcoming session
    for (final s in slots) {
      if ((s['startMinute'] as int) > nowMinutes) {
        return {...s, '_status': 'next'};
      }
    }

    return null;
  }

  // ── Greeting ──

  Widget _buildGreetingHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greeting()}, $userName',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              _todayDate(),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontSize: 13),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isTeacher
                    ? AppColors.secondary.withAlpha(30)
                    : AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isTeacher ? 'Enseignant' : (classId ?? '\u00c9tudiant'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isTeacher ? AppColors.secondary : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Stats row ──

  Widget _buildStatsRow(BuildContext context, int sessionCount, int examCount) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(
            icon: Icons.schedule_outlined,
            value: '$sessionCount',
            label: sessionCount <= 1 ? 'S\u00e9ance' : 'S\u00e9ances',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.assignment_outlined,
            value: '$examCount',
            label: examCount <= 1 ? 'Examen' : 'Examens',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: isTeacher ? Icons.people_outlined : Icons.menu_book_outlined,
            value: isTeacher ? 'GINF2' : (classId ?? '-'),
            label: isTeacher ? 'Classe' : 'Classe',
            color: AppColors.success,
          ),
        ),
      ],
    );
  }

  // ── Highlight card ──

  Widget _buildHighlightCard(BuildContext context, Map<String, dynamic> slot) {
    final isCurrent = slot['_status'] == 'current';
    final subject = slot['subjectName'] as String;
    final start = formatTime(slot['startMinute'] as int);
    final end = formatTime(slot['endMinute'] as int);
    final room = slot['room'] as String?;
    final classId = slot['classId'] as String;

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    final startMin = slot['startMinute'] as int;
    final endMin = slot['endMinute'] as int;

    // Progress for current session
    double progress = 0;
    String timeInfo = '';
    if (isCurrent) {
      progress = (nowMinutes - startMin) / (endMin - startMin);
      final remaining = endMin - nowMinutes;
      timeInfo = '$remaining min restantes';
    } else {
      final untilStart = startMin - nowMinutes;
      if (untilStart < 60) {
        timeInfo = 'Dans $untilStart min';
      } else {
        timeInfo = 'Dans ${untilStart ~/ 60}h${(untilStart % 60).toString().padLeft(2, '0')}';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCurrent
              ? [AppColors.primary, const Color(0xFF1A5BA0)]
              : [AppColors.secondary, const Color(0xFFD49920)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isCurrent ? AppColors.primary : AppColors.secondary)
                .withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isCurrent ? 'En cours' : 'Prochaine s\u00e9ance',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                timeInfo,
                style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subject,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time, size: 15, color: Colors.white.withAlpha(200)),
              const SizedBox(width: 4),
              Text(
                '$start - $end',
                style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13),
              ),
              const SizedBox(width: 16),
              Icon(Icons.location_on_outlined, size: 15, color: Colors.white.withAlpha(200)),
              const SizedBox(width: 4),
              Text(
                room ?? classId,
                style: TextStyle(color: Colors.white.withAlpha(220), fontSize: 13),
              ),
            ],
          ),
          if (isCurrent) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withAlpha(40),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Section header ──

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }

  // ── Schedule timeline ──

  Widget _buildScheduleTimeline(
      BuildContext context, List<Map<String, dynamic>> slots) {
    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;

    return Container(
      decoration: AppCardStyles.cardDecoration,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: List.generate(slots.length, (i) {
          final slot = slots[i];
          final startMin = slot['startMinute'] as int;
          final endMin = slot['endMinute'] as int;
          final isCurrent = nowMinutes >= startMin && nowMinutes < endMin;
          final isPast = nowMinutes >= endMin;
          final subject = slot['subjectName'] as String;
          final start = formatTime(startMin);
          final end = formatTime(endMin);
          final room = slot['room'] as String?;
          final classId = slot['classId'] as String;
          final teacherName = slot['teacherName'] as String;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline dot + line
                SizedBox(
                  width: 24,
                  child: Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCurrent
                              ? AppColors.primary
                              : isPast
                                  ? AppColors.textSecondary.withAlpha(80)
                                  : AppColors.secondary,
                          border: isCurrent
                              ? Border.all(
                                  color: AppColors.primary.withAlpha(60),
                                  width: 3,
                                )
                              : null,
                        ),
                      ),
                      if (i < slots.length - 1)
                        Container(
                          width: 2,
                          height: 44,
                          color: AppColors.textSecondary.withAlpha(30),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // Time
                SizedBox(
                  width: 80,
                  child: Text(
                    '$start\n$end',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isCurrent
                          ? AppColors.primary
                          : isPast
                              ? AppColors.textSecondary
                              : AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
                // Details
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? AppColors.primary.withAlpha(12)
                          : isPast
                              ? AppColors.background
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isCurrent
                          ? Border.all(
                              color: AppColors.primary.withAlpha(30))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isPast
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            ?room,
                            classId,
                            if (!isTeacher && teacherName.isNotEmpty) teacherName,
                          ].nonNulls.join(' \u2022 '),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // ── Empty card ──

  Widget _buildEmptyCard(
      BuildContext context, IconData icon, String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: AppCardStyles.cardDecoration,
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary.withAlpha(100)),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Assessment card ──

  String _shortMonth(int month) {
    const m = [
      '', 'Jan', 'F\u00e9v', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Ao\u00fb', 'Sep', 'Oct', 'Nov', 'D\u00e9c',
    ];
    return m[month];
  }

  Widget _buildAssessmentCard(
      BuildContext context, Map<String, dynamic> assessment) {
    final title = assessment['title'] as String;
    final type = assessmentTypeLabel(assessment['type'] as String);
    final classId = assessment['classId'] as String;
    final status = assessment['status'] as String;
    final dt = assessment['dateTime'] as DateTime;
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final isCanceled = status == 'canceled';

    // Check if the exam is today
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCanceled
              ? AppColors.error.withAlpha(40)
              : isToday
                  ? AppColors.primary.withAlpha(60)
                  : AppColors.secondary.withAlpha(50),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date + time badge
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isCanceled
                  ? AppColors.error.withAlpha(15)
                  : isToday
                      ? AppColors.primary.withAlpha(20)
                      : AppColors.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${dt.day}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isCanceled
                        ? AppColors.error
                        : isToday
                            ? AppColors.primary
                            : AppColors.secondary,
                  ),
                ),
                Text(
                  _shortMonth(dt.month),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCanceled
                        ? AppColors.error.withAlpha(180)
                        : isToday
                            ? AppColors.primary.withAlpha(180)
                            : AppColors.secondary.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isCanceled
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    decoration:
                        isCanceled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.class_outlined, size: 12,
                        color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Text(
                      classId,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Type + status badges
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCanceled
                      ? AppColors.error.withAlpha(20)
                      : AppColors.secondary.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isCanceled ? AppColors.error : AppColors.secondary,
                  ),
                ),
              ),
              if (isCanceled) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel(status),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              if (isToday && !isCanceled) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Aujourd\'hui',
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
        ],
      ),
    );
  }
}

// ── Shared small widgets ──

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(30)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: AppCardStyles.cardDecoration,
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withAlpha(10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withAlpha(40)),
      ),
      child: Text(
        'Erreur : $message',
        style: TextStyle(color: AppColors.error, fontSize: 13),
      ),
    );
  }
}
