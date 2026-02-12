import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'attendance_providers.dart';

/// Attendance list page showing present/absent students for a session.
class AttendanceListPage extends StatefulWidget {
  final String classId;
  final String sessionId;

  const AttendanceListPage({
    super.key,
    required this.classId,
    required this.sessionId,
  });

  @override
  State<AttendanceListPage> createState() => _AttendanceListPageState();
}

class _AttendanceListPageState extends State<AttendanceListPage> {
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    final students = await fetchClassStudents(widget.classId);
    if (mounted) {
      setState(() {
        _students = students;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liste des pr\u00e9sences'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<Map<String, Map<String, dynamic>>>(
              stream: attendanceRecordsStream(
                classId: widget.classId,
                sessionId: widget.sessionId,
              ),
              builder: (context, snapshot) {
                final records = snapshot.data ?? {};

                final present = _students
                    .where((s) => records.containsKey(s['uid']))
                    .toList();
                final absent = _students
                    .where((s) => !records.containsKey(s['uid']))
                    .toList();

                return Column(
                  children: [
                    // Summary bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: AppColors.cardSurface,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _SummaryBadge(
                            icon: Icons.check_circle_outline,
                            color: AppColors.success,
                            label: 'Pr\u00e9sents',
                            count: present.length,
                          ),
                          Container(
                            height: 40,
                            width: 1,
                            color: AppColors.textSecondary.withAlpha(40),
                          ),
                          _SummaryBadge(
                            icon: Icons.cancel_outlined,
                            color: AppColors.error,
                            label: 'Absents',
                            count: absent.length,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Student list
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          // Present section
                          if (present.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Pr\u00e9sents (${present.length})',
                              color: AppColors.success,
                            ),
                            ...present.map((s) => _StudentTile(
                                  student: s,
                                  isPresent: true,
                                  checkedAt:
                                      records[s['uid']]?['checkedAt'] as Timestamp?,
                                )),
                            const SizedBox(height: 16),
                          ],

                          // Absent section
                          if (absent.isNotEmpty) ...[
                            _SectionHeader(
                              title: 'Absents (${absent.length})',
                              color: AppColors.error,
                            ),
                            ...absent.map((s) => _StudentTile(
                                  student: s,
                                  isPresent: false,
                                )),
                          ],

                          // Empty state
                          if (_students.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'Aucun \u00e9tudiant dans cette classe.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _SummaryBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;

  const _SummaryBadge({
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 8),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
      ),
    );
  }
}

class _StudentTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isPresent;
  final Timestamp? checkedAt;

  const _StudentTile({
    required this.student,
    required this.isPresent,
    this.checkedAt,
  });

  @override
  Widget build(BuildContext context) {
    final name = student['fullName'] as String;
    final personalNumber = student['personalNumber'] as String;

    String? timeStr;
    if (checkedAt != null) {
      final dt = checkedAt!.toDate();
      timeStr =
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: AppCardStyles.cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Status icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isPresent
                  ? AppColors.success.withAlpha(25)
                  : AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPresent ? Icons.check : Icons.close,
              color: isPresent ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Name and number
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (personalNumber.isNotEmpty)
                  Text(
                    personalNumber,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),

          // Check-in time for present students
          if (isPresent && timeStr != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
