import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../auth/auth_providers.dart';
import 'attendance_providers.dart';
import 'qr_display_page.dart';
import 'qr_scanner_page.dart';

/// Pr\u00e9sences page.
/// - Teacher: select a session, open QR.
/// - Student: placeholder (scanner added in session-008).
class AttendancePage extends ConsumerStatefulWidget {
  const AttendancePage({super.key});

  @override
  ConsumerState<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends ConsumerState<AttendancePage> {
  Map<String, dynamic>? _selectedSlot;
  bool _loading = false;

  String _formatTime(int totalMinutes) {
    final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _openQr() async {
    if (_selectedSlot == null) return;

    setState(() => _loading = true);

    try {
      final result = await callCreateAttendanceSession(
        classId: _selectedSlot!['classId'] as String,
        timetableSlotId: _selectedSlot!['slotId'] as String,
      );

      if (!mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QrDisplayPage(
            classId: _selectedSlot!['classId'] as String,
            sessionId: result['sessionId'] as String,
            token: result['token'] as String,
            expiresAt: DateTime.parse(result['expiresAt'] as String),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserProvider);

    return appUser.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur : $e')),
      data: (user) {
        if (user == null) {
          return const Center(child: Text('Utilisateur introuvable.'));
        }
        if (user.isTeacher) {
          return _buildTeacherView(context);
        }
        return _buildStudentView(context);
      },
    );
  }

  Widget _buildTeacherView(BuildContext context) {
    final slotsAsync = ref.watch(teacherTodaySlotsProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Session selector card
          Container(
            decoration: AppCardStyles.cardDecoration,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'S\u00e9ances d\'aujourd\'hui',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                slotsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Erreur : $e'),
                  data: (slots) {
                    if (slots.isEmpty) {
                      return Text(
                        'Aucune s\u00e9ance aujourd\'hui.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      );
                    }
                    return DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                        labelText: 'Choisir une s\u00e9ance',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.schedule_outlined),
                      ),
                      initialValue: _selectedSlot,
                      isExpanded: true,
                      items: slots.map((slot) {
                        final start =
                            _formatTime(slot['startMinute'] as int);
                        final end =
                            _formatTime(slot['endMinute'] as int);
                        final room = slot['room'] as String?;
                        final classId = slot['classId'] as String;
                        final label =
                            '$start - $end | $classId${room != null ? ' | $room' : ''}';
                        return DropdownMenuItem(
                          value: slot,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedSlot = value);
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Open QR button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  (_selectedSlot != null && !_loading) ? _openQr : null,
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code),
              label: const Text('Ouvrir QR (3 min)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_scanner,
                size: 80, color: AppColors.primary.withAlpha(180)),
            const SizedBox(height: 24),
            Text(
              'Scanner de pr\u00e9sence',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Scannez le QR code affich\u00e9 par votre enseignant\n'
              'pour enregistrer votre pr\u00e9sence.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const QrScannerPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scanner QR'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
