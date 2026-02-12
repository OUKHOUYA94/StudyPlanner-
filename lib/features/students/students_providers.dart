import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Fetches students for a specific class with their profiles.
/// Returns list of { uid, fullName, personalNumber, photoURL }.
final classStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) async {
  final db = FirebaseFirestore.instance;

  // Get student member UIDs
  final membersSnap = await db
      .collection('classes')
      .doc(classId)
      .collection('members')
      .where('role', isEqualTo: 'student')
      .get();

  final List<Map<String, dynamic>> students = [];

  for (final memberDoc in membersSnap.docs) {
    final uid = memberDoc.id;
    final userDoc = await db.collection('users').doc(uid).get();
    if (userDoc.exists) {
      final data = userDoc.data()!;
      students.add({
        'uid': uid,
        'fullName': data['fullName'] ?? '',
        'personalNumber': data['personalNumber'] ?? '',
        'photoURL': data['photoURL'],
      });
    }
  }

  students
      .sort((a, b) => (a['fullName'] as String).compareTo(b['fullName'] as String));
  return students;
});

/// Fetches teacher's classes with student counts.
/// Returns list of { classId, className, studentCount }.
final teacherClassesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null || !appUser.isTeacher) return [];

  final db = FirebaseFirestore.instance;
  final classIds = appUser.teacherClassIds ?? [];
  final List<Map<String, dynamic>> classes = [];

  for (final classId in classIds) {
    // Get class name
    final classDoc = await db.collection('classes').doc(classId).get();
    final className = classDoc.data()?['name'] ?? classId;

    // Count students
    final countSnap = await db
        .collection('classes')
        .doc(classId)
        .collection('members')
        .where('role', isEqualTo: 'student')
        .count()
        .get();

    classes.add({
      'classId': classId,
      'className': className,
      'studentCount': countSnap.count ?? 0,
    });
  }

  classes.sort((a, b) =>
      (a['className'] as String).compareTo(b['className'] as String));
  return classes;
});
