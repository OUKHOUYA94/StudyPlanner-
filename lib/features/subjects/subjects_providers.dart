import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Fetches subjects for the current user.
/// Student: all subjects from their class.
/// Teacher: only subjects they teach, across all assigned classes.
final subjectsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return [];

  final db = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> subjects = [];

  if (appUser.isStudent) {
    // Student: fetch all subjects from own class
    final classId = appUser.classId;
    if (classId == null) return [];

    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('subjects')
        .orderBy('name')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      subjects.add({
        'subjectId': doc.id,
        'classId': classId,
        'name': data['name'] ?? doc.id,
        'teacherUid': data['teacherUid'] ?? '',
        'teacherName': data['teacherName'] ?? '',
        'active': data['active'] ?? true,
      });
    }
  } else {
    // Teacher: fetch subjects they teach from each assigned class
    final classIds = appUser.teacherClassIds ?? [];

    for (final classId in classIds) {
      final snap = await db
          .collection('classes')
          .doc(classId)
          .collection('subjects')
          .where('teacherUid', isEqualTo: appUser.uid)
          .orderBy('name')
          .get();

      for (final doc in snap.docs) {
        final data = doc.data();
        subjects.add({
          'subjectId': doc.id,
          'classId': classId,
          'name': data['name'] ?? doc.id,
          'teacherUid': data['teacherUid'] ?? '',
          'teacherName': data['teacherName'] ?? '',
          'active': data['active'] ?? true,
        });
      }
    }
  }

  return subjects;
});

/// Fetches timetable slots for a specific subject in a class.
final subjectScheduleProvider = FutureProvider.family<
    List<Map<String, dynamic>>, ({String classId, String subjectId})>(
  (ref, params) async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection('classes')
        .doc(params.classId)
        .collection('timetableSlots')
        .where('subjectId', isEqualTo: params.subjectId)
        .orderBy('dayOfWeek')
        .orderBy('startMinute')
        .get();

    return snap.docs.map((doc) {
      final data = doc.data();
      return {
        'slotId': doc.id,
        'dayOfWeek': data['dayOfWeek'],
        'startMinute': data['startMinute'],
        'endMinute': data['endMinute'],
        'room': data['room'],
      };
    }).toList();
  },
);
