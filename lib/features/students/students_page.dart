import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import 'students_providers.dart';

/// Color palette for class headers.
const _classColors = [
  Color(0xFF4A90D9),
  Color(0xFFE8724A),
  Color(0xFF50B88E),
  Color(0xFF9B59B6),
  Color(0xFFE74C8B),
  Color(0xFFF2994A),
  Color(0xFF2EC4B6),
];

Color _colorForClass(String classId) {
  return _classColors[classId.hashCode.abs() % _classColors.length];
}

/// Avatar color from student name.
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

/// Page for teachers to view students in their classes.
class StudentsPage extends ConsumerStatefulWidget {
  const StudentsPage({super.key});

  @override
  ConsumerState<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends ConsumerState<StudentsPage> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(teacherClassesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('\u00c9tudiants'),
      ),
      body: classesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (classes) {
          if (classes.isEmpty) {
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
                      child: Icon(Icons.people_outline,
                          size: 42, color: AppColors.primary.withAlpha(120)),
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
                      'Vous n\u2019\u00eates assign\u00e9 \u00e0 aucune classe.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          // Total students across all classes
          final totalStudents = classes.fold<int>(
              0, (sum, c) => sum + (c['studentCount'] as int));

          return Column(
            children: [
              // ── Search bar + stats ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Stats row
                    Row(
                      children: [
                        _StatChip(
                          icon: Icons.school_outlined,
                          label: '${classes.length}',
                          subtitle: classes.length > 1 ? 'classes' : 'classe',
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatChip(
                          icon: Icons.people_outline,
                          label: '$totalStudents',
                          subtitle: '\u00e9tudiants',
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      decoration: InputDecoration(
                        hintText: 'Rechercher un \u00e9tudiant...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(Icons.search,
                            color: AppColors.textSecondary.withAlpha(150)),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Class sections ──
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: classes.length,
                  itemBuilder: (context, index) {
                    final classInfo = classes[index];
                    return _ClassSection(
                      classId: classInfo['classId'] as String,
                      className: classInfo['className'] as String,
                      studentCount: classInfo['studentCount'] as int,
                      searchQuery: _search,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stat chip ────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(30)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withAlpha(160),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Class section with header + students ─────────────────────────────

class _ClassSection extends ConsumerWidget {
  final String classId;
  final String className;
  final int studentCount;
  final String searchQuery;

  const _ClassSection({
    required this.classId,
    required this.className,
    required this.studentCount,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _colorForClass(classId);
    final studentsAsync = ref.watch(classStudentsProvider(classId));

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Class header card ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withAlpha(180)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(40),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$studentCount \u00e9tudiant${studentCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(190),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    classId,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withAlpha(220),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Student list ──
          studentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Erreur : $e',
                  style: TextStyle(color: AppColors.error)),
            ),
            data: (students) {
              // Filter by search
              final query = searchQuery.toLowerCase();
              final filtered = query.isEmpty
                  ? students
                  : students
                      .where((s) =>
                          (s['fullName'] as String)
                              .toLowerCase()
                              .contains(query) ||
                          (s['personalNumber'] as String)
                              .toLowerCase()
                              .contains(query))
                      .toList();

              if (filtered.isEmpty) {
                if (students.isEmpty) {
                  return _EmptyStudents(
                      message: 'Aucun \u00e9tudiant dans cette classe.');
                }
                return _EmptyStudents(
                    message: 'Aucun r\u00e9sultat pour "$searchQuery".');
              }

              return Column(
                children: [
                  for (int i = 0; i < filtered.length; i++)
                    _StudentCard(
                      student: filtered[i],
                      index: i + 1,
                      classColor: color,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Empty students message ───────────────────────────────────────────

class _EmptyStudents extends StatelessWidget {
  final String message;
  const _EmptyStudents({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withAlpha(8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textSecondary.withAlpha(25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline,
              size: 16, color: AppColors.textSecondary.withAlpha(150)),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Student card ─────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  final Color classColor;

  const _StudentCard({
    required this.student,
    required this.index,
    required this.classColor,
  });

  @override
  Widget build(BuildContext context) {
    final fullName = student['fullName'] as String;
    final personalNumber = student['personalNumber'] as String;
    final photoURL = student['photoURL'] as String?;
    final uid = student['uid'] as String;
    final color = _avatarColor(uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.textSecondary.withAlpha(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Number badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: classColor.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: classColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 10),

            // Avatar
            _buildAvatar(fullName, photoURL, color),

            const SizedBox(width: 12),

            // Name + personal number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        personalNumber,
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

            // Status dot (online indicator placeholder)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(120),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String name, String? photoURL, Color color) {
    if (photoURL != null) {
      ImageProvider image;
      if (photoURL.startsWith('data:')) {
        image = MemoryImage(base64Decode(photoURL.split(',')[1]));
      } else {
        image = NetworkImage(photoURL);
      }
      return CircleAvatar(
        radius: 20,
        backgroundImage: image,
        backgroundColor: color.withAlpha(20),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}
