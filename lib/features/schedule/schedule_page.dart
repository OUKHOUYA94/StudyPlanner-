import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import 'schedule_providers.dart';

/// Subject-based color palette for visual distinction.
const _subjectColors = [
  Color(0xFF4A90D9), // blue
  Color(0xFFE8724A), // orange
  Color(0xFF50B88E), // green
  Color(0xFF9B59B6), // purple
  Color(0xFFE74C8B), // pink
  Color(0xFFF2994A), // amber
  Color(0xFF2EC4B6), // teal
];

Color _colorForSubject(String subjectId) {
  final idx = subjectId.hashCode.abs() % _subjectColors.length;
  return _subjectColors[idx];
}

/// Short day abbreviation in French.
const _dayAbbr = {
  1: 'Lun',
  2: 'Mar',
  3: 'Mer',
  4: 'Jeu',
  5: 'Ven',
  6: 'Sam',
  7: 'Dim',
};

/// Schedule page with tabs for today and full week view.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isTeacher = appUser?.isTeacher ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emploi du temps'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.secondary,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          tabs: const [
            Tab(
              icon: Icon(Icons.today_rounded, size: 20),
              text: 'Aujourd\'hui',
            ),
            Tab(
              icon: Icon(Icons.calendar_view_week_rounded, size: 20),
              text: 'Semaine',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _TodayTab(),
          _WeekTab(),
        ],
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateForm(context, ref),
              backgroundColor: AppColors.secondary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'Nouvelle séance',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  void _openCreateForm(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const _SlotFormPage()),
    );
    if (result == true) {
      ref.invalidate(todaySlotsProvider);
      ref.invalidate(weekSlotsProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// TODAY TAB
// ─────────────────────────────────────────────────────────────

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slotsAsync = ref.watch(todaySlotsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isTeacher = appUser?.isTeacher ?? false;

    return slotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: '$e'),
      data: (allSlots) {
        // Teacher sees only their own sessions
        final slots = isTeacher
            ? allSlots
                .where((s) => s['teacherUid'] == appUser?.uid)
                .toList()
            : allSlots;

        if (slots.isEmpty) {
          return _EmptyView(
            icon: Icons.wb_sunny_outlined,
            title: 'Pas de cours aujourd\'hui',
            subtitle: 'Profitez de votre journée libre !',
          );
        }

        final now = DateTime.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final todayDow = now.weekday;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
          children: [
            _TodayHeader(
                todayDow: todayDow, now: now, slotCount: slots.length),
            const SizedBox(height: 20),
            ...List.generate(slots.length, (i) {
              final slot = slots[i];
              final status = slot['status'] as String;
              final isCanceled = status == 'canceled';
              final startMin = slot['startMinute'] as int;
              final endMin = slot['endMinute'] as int;
              final isCurrent =
                  !isCanceled && nowMinutes >= startMin && nowMinutes < endMin;
              final isPast = !isCanceled && nowMinutes >= endMin;

              return _TimelineSlotCard(
                slot: slot,
                isCurrent: isCurrent,
                isPast: isPast,
                isCanceled: isCanceled,
                isFirst: i == 0,
                isLast: i == slots.length - 1,
                nowMinutes: nowMinutes,
                isTeacher: isTeacher,
                onCancel: isTeacher && !isCanceled
                    ? () => _confirmCancel(context, ref, slot)
                    : null,
                onRestore: isTeacher && isCanceled
                    ? () => _restoreSlot(context, ref, slot)
                    : null,
              );
            }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEEK TAB
// ─────────────────────────────────────────────────────────────

class _WeekTab extends ConsumerStatefulWidget {
  const _WeekTab();

  @override
  ConsumerState<_WeekTab> createState() => _WeekTabState();
}

class _WeekTabState extends ConsumerState<_WeekTab> {
  int _selectedDay = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final weekAsync = ref.watch(weekSlotsProvider);
    final appUser = ref.watch(appUserProvider).valueOrNull;
    final isTeacher = appUser?.isTeacher ?? false;

    return weekAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(message: '$e'),
      data: (grouped) {
        if (grouped.isEmpty) {
          return _EmptyView(
            icon: Icons.calendar_month_outlined,
            title: 'Aucun emploi du temps',
            subtitle: 'Pas de séances programmées cette semaine.',
          );
        }

        final filteredGrouped = <int, List<Map<String, dynamic>>>{};
        for (final entry in grouped.entries) {
          final filtered = isTeacher
              ? entry.value
                  .where((s) => s['teacherUid'] == appUser?.uid)
                  .toList()
              : entry.value;
          if (filtered.isNotEmpty) {
            filteredGrouped[entry.key] = filtered;
          }
        }

        final allDays = filteredGrouped.keys.toList()..sort();
        if (!allDays.contains(_selectedDay) && allDays.isNotEmpty) {
          _selectedDay = allDays.first;
        }

        final selectedSlots = filteredGrouped[_selectedDay] ?? [];

        return Column(
          children: [
            const SizedBox(height: 16),
            // ── Day selector chips ──
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: 6,
                itemBuilder: (context, i) {
                  final dow = i + 1;
                  final isSelected = dow == _selectedDay;
                  final hasSlots = filteredGrouped.containsKey(dow);
                  final count = filteredGrouped[dow]?.length ?? 0;
                  final isToday = dow == DateTime.now().weekday;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: hasSlots
                          ? () => setState(() => _selectedDay = dow)
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 56,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : hasSlots
                                  ? Colors.white
                                  : AppColors.textSecondary.withAlpha(15),
                          borderRadius: BorderRadius.circular(16),
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: AppColors.secondary, width: 2)
                              : Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.textSecondary.withAlpha(40),
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(50),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _dayAbbr[dow] ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : hasSlots
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary
                                            .withAlpha(120),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (hasSlots)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white.withAlpha(50)
                                      : AppColors.primary.withAlpha(20),
                                ),
                                child: Center(
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primary,
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      AppColors.textSecondary.withAlpha(100),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // ── Day header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    dayName(_selectedDay),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${selectedSlots.length} séance${selectedSlots.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Slots list ──
            Expanded(
              child: selectedSlots.isEmpty
                  ? Center(
                      child: Text(
                        'Aucun cours ce jour.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: selectedSlots.length,
                      itemBuilder: (context, i) {
                        final slot = selectedSlots[i];
                        final isCanceled =
                            (slot['status'] as String) == 'canceled';
                        return _WeekSlotCard(
                          slot: slot,
                          index: i,
                          isTeacher: isTeacher,
                          isCanceled: isCanceled,
                          onCancel: isTeacher && !isCanceled
                              ? () => _confirmCancel(context, ref, slot)
                              : null,
                          onRestore: isTeacher && isCanceled
                              ? () => _restoreSlot(context, ref, slot)
                              : null,
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED ACTIONS
// ─────────────────────────────────────────────────────────────

Future<void> _confirmCancel(
    BuildContext context, WidgetRef ref, Map<String, dynamic> slot) async {
  final subjectName = slot['subjectName'] as String;
  final subjectId = slot['subjectId'] as String;
  final display = subjectName.isNotEmpty ? subjectName : subjectId;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Annuler la séance ?'),
      content: Text(
        'Voulez-vous annuler la séance de "$display" ?\n'
        'Les étudiants verront cette séance comme annulée.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Non'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Oui, annuler'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await callCancelSlot(
      classId: slot['classId'] as String,
      slotId: slot['slotId'] as String,
    );
    ref.invalidate(todaySlotsProvider);
    ref.invalidate(weekSlotsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Séance annulée.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

Future<void> _restoreSlot(
    BuildContext context, WidgetRef ref, Map<String, dynamic> slot) async {
  try {
    await callRestoreSlot(
      classId: slot['classId'] as String,
      slotId: slot['slotId'] as String,
    );
    ref.invalidate(todaySlotsProvider);
    ref.invalidate(weekSlotsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Séance restaurée.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────
// TODAY HEADER
// ─────────────────────────────────────────────────────────────

class _TodayHeader extends StatelessWidget {
  final int todayDow;
  final DateTime now;
  final int slotCount;

  const _TodayHeader({
    required this.todayDow,
    required this.now,
    required this.slotCount,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      '', 'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
    ];
    final dateStr =
        '${dayName(todayDow)} ${now.day} ${months[now.month]} ${now.year}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${now.day}',
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                Text(
                  _dayAbbr[todayDow] ?? '',
                  style: TextStyle(
                      fontSize: 11, color: Colors.white.withAlpha(200)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  '$slotCount séance${slotCount > 1 ? 's' : ''} prévue${slotCount > 1 ? 's' : ''}',
                  style:
                      TextStyle(fontSize: 13, color: Colors.white.withAlpha(180)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$slotCount',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TIMELINE SLOT CARD (Today tab)
// ─────────────────────────────────────────────────────────────

class _TimelineSlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final bool isCurrent;
  final bool isPast;
  final bool isCanceled;
  final bool isFirst;
  final bool isLast;
  final int nowMinutes;
  final bool isTeacher;
  final VoidCallback? onCancel;
  final VoidCallback? onRestore;

  const _TimelineSlotCard({
    required this.slot,
    required this.isCurrent,
    required this.isPast,
    required this.isCanceled,
    required this.isFirst,
    required this.isLast,
    required this.nowMinutes,
    required this.isTeacher,
    this.onCancel,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final subjectId = slot['subjectId'] as String;
    final subjectName = slot['subjectName'] as String;
    final teacherName = slot['teacherName'] as String;
    final classId = slot['classId'] as String;
    final room = slot['room'] as String?;
    final startMin = slot['startMinute'] as int;
    final endMin = slot['endMinute'] as int;
    final color = isCanceled
        ? AppColors.textSecondary
        : _colorForSubject(subjectId);
    final displayName = subjectName.isNotEmpty ? subjectName : subjectId;

    double progress = 0;
    if (isCurrent && endMin > startMin) {
      progress = (nowMinutes - startMin) / (endMin - startMin);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Timeline rail ──
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isPast || isCurrent
                          ? color.withAlpha(150)
                          : AppColors.textSecondary.withAlpha(60),
                    ),
                  ),
                Container(
                  width: isCurrent ? 16 : 12,
                  height: isCurrent ? 16 : 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCanceled
                        ? AppColors.error.withAlpha(60)
                        : isCurrent
                            ? color
                            : isPast
                                ? color.withAlpha(120)
                                : Colors.white,
                    border: Border.all(
                      color: isCanceled ? AppColors.error : color,
                      width: isCurrent ? 3 : 2,
                    ),
                    boxShadow: isCurrent
                        ? [
                            BoxShadow(
                              color: color.withAlpha(80),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isPast
                          ? color.withAlpha(150)
                          : AppColors.textSecondary.withAlpha(60),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Card ──
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isCanceled
                      ? AppColors.error.withAlpha(8)
                      : isCurrent
                          ? color.withAlpha(15)
                          : isPast
                              ? Colors.white.withAlpha(200)
                              : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: isCanceled
                      ? Border.all(
                          color: AppColors.error.withAlpha(60), width: 1)
                      : isCurrent
                          ? Border.all(color: color, width: 1.5)
                          : Border.all(
                              color: AppColors.textSecondary.withAlpha(30)),
                  boxShadow: [
                    BoxShadow(
                      color: isCurrent
                          ? color.withAlpha(25)
                          : Colors.black.withAlpha(8),
                      blurRadius: isCurrent ? 12 : 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time + status badges + teacher action
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCanceled
                                ? AppColors.error.withAlpha(20)
                                : color.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${formatTime(startMin)} - ${formatTime(endMin)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCanceled ? AppColors.error : color,
                              decoration: isCanceled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isCanceled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'ANNULÉE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'EN COURS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                        if (isPast && !isCanceled) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Terminé',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary.withAlpha(150),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Teacher actions
                        if (onCancel != null)
                          _ActionButton(
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            onTap: onCancel!,
                          ),
                        if (onRestore != null)
                          _ActionButton(
                            icon: Icons.restore,
                            color: AppColors.success,
                            onTap: onRestore!,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Subject name
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isCanceled
                            ? AppColors.textSecondary
                            : isPast
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                        decoration:
                            isCanceled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Meta
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _MetaChip(
                            icon: Icons.class_outlined,
                            label: classId,
                            faded: isPast || isCanceled),
                        if (!isTeacher && teacherName.isNotEmpty)
                          _MetaChip(
                              icon: Icons.person_outline_rounded,
                              label: teacherName,
                              faded: isPast || isCanceled),
                        if (room != null && room.isNotEmpty)
                          _MetaChip(
                              icon: Icons.room_outlined,
                              label: room,
                              faded: isPast || isCanceled),
                      ],
                    ),

                    if (isCurrent) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: color.withAlpha(40),
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WEEK SLOT CARD
// ─────────────────────────────────────────────────────────────

class _WeekSlotCard extends StatelessWidget {
  final Map<String, dynamic> slot;
  final int index;
  final bool isTeacher;
  final bool isCanceled;
  final VoidCallback? onCancel;
  final VoidCallback? onRestore;

  const _WeekSlotCard({
    required this.slot,
    required this.index,
    required this.isTeacher,
    required this.isCanceled,
    this.onCancel,
    this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final subjectId = slot['subjectId'] as String;
    final subjectName = slot['subjectName'] as String;
    final teacherName = slot['teacherName'] as String;
    final classId = slot['classId'] as String;
    final room = slot['room'] as String?;
    final startMin = slot['startMinute'] as int;
    final endMin = slot['endMinute'] as int;
    final color =
        isCanceled ? AppColors.textSecondary : _colorForSubject(subjectId);
    final displayName = subjectName.isNotEmpty ? subjectName : subjectId;
    final durationMin = endMin - startMin;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: isCanceled ? AppColors.error.withAlpha(8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCanceled
                ? AppColors.error.withAlpha(50)
                : AppColors.textSecondary.withAlpha(25),
          ),
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
            // Colored side bar
            Container(
              width: 5,
              height: 80,
              decoration: BoxDecoration(
                color: isCanceled ? AppColors.error.withAlpha(120) : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),

            // Time column
            Container(
              width: 70,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Text(
                    formatTime(startMin),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isCanceled ? AppColors.error : color,
                      decoration:
                          isCanceled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 10,
                    color: AppColors.textSecondary.withAlpha(60),
                  ),
                  Text(
                    formatTime(endMin),
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      decoration:
                          isCanceled ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${durationMin}min',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withAlpha(130),
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            Container(
              width: 1,
              height: 50,
              color: AppColors.textSecondary.withAlpha(30),
            ),

            // Info column
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isCanceled
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: isCanceled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (isCanceled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ANNULÉE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              _MetaChip(
                                  icon: Icons.class_outlined,
                                  label: classId,
                                  faded: isCanceled),
                              if (!isTeacher && teacherName.isNotEmpty)
                                _MetaChip(
                                    icon: Icons.person_outline_rounded,
                                    label: teacherName,
                                    faded: isCanceled),
                              if (room != null && room.isNotEmpty)
                                _MetaChip(
                                    icon: Icons.room_outlined,
                                    label: room,
                                    faded: isCanceled),
                            ],
                          ),
                        ),
                        // Teacher action button
                        if (onCancel != null)
                          _ActionButton(
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            onTap: onCancel!,
                          ),
                        if (onRestore != null)
                          _ActionButton(
                            icon: Icons.restore,
                            color: AppColors.success,
                            onTap: onRestore!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool faded;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.faded,
  });

  @override
  Widget build(BuildContext context) {
    final c =
        faded ? AppColors.textSecondary.withAlpha(120) : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: c)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon,
                  size: 40, color: AppColors.primary.withAlpha(120)),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Erreur de chargement',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message,
                style:
                    TextStyle(fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SLOT CREATION FORM (Teacher only)
// ─────────────────────────────────────────────────────────────

class _SlotFormPage extends ConsumerStatefulWidget {
  const _SlotFormPage();

  @override
  ConsumerState<_SlotFormPage> createState() => _SlotFormPageState();
}

class _SlotFormPageState extends ConsumerState<_SlotFormPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedClassId;
  String? _selectedSubjectId;
  // Default to today, but clamp to Mon-Sat (1-6) since Sunday isn't offered
  int _selectedDay = DateTime.now().weekday > 6 ? 1 : DateTime.now().weekday;
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 30);
  final _roomController = TextEditingController();

  List<String> _classIds = [];
  Map<String, String> _subjectMap = {};
  bool _loadingSubjects = false;
  bool _submitting = false;

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjects(String classId) async {
    setState(() => _loadingSubjects = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      var query = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .collection('subjects')
          .orderBy('name');

      if (uid != null) {
        query = query.where('teacherUid', isEqualTo: uid);
      }

      final snap = await query.get();
      final map = <String, String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        map[doc.id] = (data['name'] as String?) ?? doc.id;
      }

      setState(() {
        _subjectMap = map;
        if (!_subjectMap.containsKey(_selectedSubjectId)) {
          _selectedSubjectId =
              _subjectMap.isNotEmpty ? _subjectMap.keys.first : null;
        }
        _loadingSubjects = false;
      });
    } catch (e) {
      setState(() => _loadingSubjects = false);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          // Auto-adjust end time if it's before start
          final startMin = picked.hour * 60 + picked.minute;
          final endMin = _endTime.hour * 60 + _endTime.minute;
          if (endMin <= startMin) {
            _endTime = TimeOfDay(
                hour: (startMin + 90) ~/ 60, minute: (startMin + 90) % 60);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null || _selectedSubjectId == null) return;

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin = _endTime.hour * 60 + _endTime.minute;

    if (endMin <= startMin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'heure de fin doit être après l\'heure de début.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await callCreateSlot(
        classId: _selectedClassId!,
        subjectId: _selectedSubjectId!,
        subjectName: _subjectMap[_selectedSubjectId!] ?? _selectedSubjectId!,
        dayOfWeek: _selectedDay,
        startMinute: startMin,
        endMinute: endMin,
        room: _roomController.text.trim().isEmpty
            ? null
            : _roomController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Séance créée avec succès.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Erreur : $e'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider).valueOrNull;
    if (_classIds.isEmpty && appUser != null) {
      _classIds = appUser.teacherClassIds ?? [];
      if (_selectedClassId == null && _classIds.isNotEmpty) {
        _selectedClassId = _classIds.first;
        _loadSubjects(_selectedClassId!);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle séance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Class
              DropdownButtonFormField<String>(
                key: ValueKey('class_$_selectedClassId'),
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Classe',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                items: _classIds
                    .map((id) =>
                        DropdownMenuItem(value: id, child: Text(id)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedClassId = value;
                    _selectedSubjectId = null;
                    _subjectMap = {};
                  });
                  if (value != null) _loadSubjects(value);
                },
                validator: (v) =>
                    v == null ? 'Veuillez sélectionner une classe.' : null,
              ),
              const SizedBox(height: 16),

              // Subject
              _loadingSubjects
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : DropdownButtonFormField<String>(
                      key: ValueKey('subject_${_selectedClassId}_$_selectedSubjectId'),
                      initialValue: _selectedSubjectId,
                      decoration: const InputDecoration(
                        labelText: 'Matière',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.book_outlined),
                      ),
                      items: _subjectMap.entries
                          .map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (value) {
                        setState(() => _selectedSubjectId = value);
                      },
                      validator: (v) => v == null
                          ? 'Veuillez sélectionner une matière.'
                          : null,
                    ),
              const SizedBox(height: 16),

              // Day of week
              DropdownButtonFormField<int>(
                key: ValueKey('day_$_selectedDay'),
                initialValue: _selectedDay,
                decoration: const InputDecoration(
                  labelText: 'Jour',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                items: List.generate(6, (i) {
                  final dow = i + 1;
                  return DropdownMenuItem(
                      value: dow, child: Text(dayName(dow)));
                }),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedDay = value);
                },
              ),
              const SizedBox(height: 16),

              // Start / End times
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isStart: true),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Début',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pickTime(isStart: false),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fin',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time_filled),
                        ),
                        child: Text(
                          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Room
              TextFormField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Salle (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.room_outlined),
                ),
              ),
              const SizedBox(height: 32),

              // Submit
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    _submitting ? 'Création...' : 'Créer la séance',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
