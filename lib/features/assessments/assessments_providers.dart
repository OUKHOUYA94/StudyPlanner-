import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Today's assessments for the current user's class(es).
/// Student: own class. Teacher: all assigned classes.
final todayAssessmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return [];

  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final todayEnd = todayStart.add(const Duration(days: 1));

  final classIds = appUser.isStudent
      ? [if (appUser.classId != null) appUser.classId!]
      : (appUser.teacherClassIds ?? []);

  final List<Map<String, dynamic>> assessments = [];

  for (final classId in classIds) {
    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('assessments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('dateTime', isLessThan: Timestamp.fromDate(todayEnd))
        .orderBy('dateTime')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      assessments.add({
        'assessmentId': doc.id,
        'classId': classId,
        'subjectId': data['subjectId'] ?? '',
        'title': data['title'] ?? '',
        'type': data['type'] ?? '',
        'status': data['status'] ?? 'scheduled',
        'dateTime': (data['dateTime'] as Timestamp).toDate(),
      });
    }
  }

  assessments.sort((a, b) =>
      (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
  return assessments;
});

/// This week's assessments for the current user's class(es).
/// Grouped by date.
final weekAssessmentsProvider =
    FutureProvider<Map<DateTime, List<Map<String, dynamic>>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return {};

  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  // Start of week (Monday)
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final mondayStart =
      DateTime(weekStart.year, weekStart.month, weekStart.day);
  final sundayEnd = mondayStart.add(const Duration(days: 7));

  final classIds = appUser.isStudent
      ? [if (appUser.classId != null) appUser.classId!]
      : (appUser.teacherClassIds ?? []);

  final Map<DateTime, List<Map<String, dynamic>>> grouped = {};

  for (final classId in classIds) {
    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('assessments')
        .where('dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(mondayStart))
        .where('dateTime', isLessThan: Timestamp.fromDate(sundayEnd))
        .orderBy('dateTime')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final dt = (data['dateTime'] as Timestamp).toDate();
      final dayKey = DateTime(dt.year, dt.month, dt.day);

      final assessment = {
        'assessmentId': doc.id,
        'classId': classId,
        'subjectId': data['subjectId'] ?? '',
        'title': data['title'] ?? '',
        'type': data['type'] ?? '',
        'status': data['status'] ?? 'scheduled',
        'dateTime': dt,
      };

      grouped.putIfAbsent(dayKey, () => []).add(assessment);
    }
  }

  return grouped;
});

/// Upcoming scheduled assessments (from today onwards) for the dashboard.
/// Returns the next assessments sorted by date, limited to keep the UI clean.
final upcomingAssessmentsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return [];

  final db = FirebaseFirestore.instance;
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  final classIds = appUser.isStudent
      ? [if (appUser.classId != null) appUser.classId!]
      : (appUser.teacherClassIds ?? []);

  final List<Map<String, dynamic>> assessments = [];

  for (final classId in classIds) {
    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('assessments')
        .where('dateTime',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .orderBy('dateTime')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      assessments.add({
        'assessmentId': doc.id,
        'classId': classId,
        'subjectId': data['subjectId'] ?? '',
        'title': data['title'] ?? '',
        'type': data['type'] ?? '',
        'status': data['status'] ?? 'scheduled',
        'dateTime': (data['dateTime'] as Timestamp).toDate(),
      });
    }
  }

  assessments.sort((a, b) =>
      (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime));
  return assessments;
});

/// Format assessment type to French label.
String assessmentTypeLabel(String type) {
  const labels = {
    'exam': 'Examen',
    'quiz': 'Quiz',
    'homework': 'Devoir',
    'project': 'Projet',
    'oral': 'Oral',
  };
  return labels[type] ?? type;
}

/// Status color helper.
String statusLabel(String status) {
  const labels = {
    'scheduled': 'Programmé',
    'canceled': 'Annulé',
    'completed': 'Terminé',
  };
  return labels[status] ?? status;
}

/// Creates an assessment directly in Firestore.
/// Returns { assessmentId: string }.
Future<Map<String, dynamic>> callCreateAssessment({
  required String classId,
  required String subjectId,
  required String title,
  required String type,
  required DateTime dateTime,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Authentification requise.');

  final ref = await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('assessments')
      .add({
    'subjectId': subjectId,
    'title': title,
    'type': type,
    'dateTime': Timestamp.fromDate(dateTime),
    'status': 'scheduled',
    'teacherUid': uid,
    'createdAt': FieldValue.serverTimestamp(),
  });

  return {'assessmentId': ref.id};
}

/// Updates an assessment directly in Firestore.
/// Returns { success: true }.
Future<Map<String, dynamic>> callUpdateAssessment({
  required String classId,
  required String assessmentId,
  String? title,
  String? type,
  String? subjectId,
  DateTime? dateTime,
}) async {
  final data = <String, dynamic>{
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (title != null) data['title'] = title;
  if (type != null) data['type'] = type;
  if (subjectId != null) data['subjectId'] = subjectId;
  if (dateTime != null) data['dateTime'] = Timestamp.fromDate(dateTime);

  await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('assessments')
      .doc(assessmentId)
      .update(data);

  return {'success': true};
}

/// Cancels an assessment directly in Firestore.
/// Returns { success: true }.
Future<Map<String, dynamic>> callCancelAssessment({
  required String classId,
  required String assessmentId,
  String? reason,
}) async {
  final data = <String, dynamic>{
    'status': 'canceled',
    'updatedAt': FieldValue.serverTimestamp(),
  };
  if (reason != null) data['cancelReason'] = reason;

  await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('assessments')
      .doc(assessmentId)
      .update(data);

  return {'success': true};
}
