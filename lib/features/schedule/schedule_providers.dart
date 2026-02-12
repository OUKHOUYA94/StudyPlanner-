import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Today's timetable slots for the current user.
/// Student: own class. Teacher: all assigned classes.
final todaySlotsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return [];

  final db = FirebaseFirestore.instance;
  final todayDow = DateTime.now().weekday; // 1=Mon..7=Sun
  final List<Map<String, dynamic>> slots = [];

  final classIds = appUser.isStudent
      ? [if (appUser.classId != null) appUser.classId!]
      : (appUser.teacherClassIds ?? []);

  for (final classId in classIds) {
    var query = db
        .collection('classes')
        .doc(classId)
        .collection('timetableSlots')
        .where('dayOfWeek', isEqualTo: todayDow)
        .orderBy('startMinute');

    final snap = await query.get();

    for (final doc in snap.docs) {
      final data = doc.data();
      slots.add({
        'classId': classId,
        'slotId': doc.id,
        'subjectId': data['subjectId'] ?? '',
        'subjectName': data['subjectName'] ?? data['subjectId'] ?? '',
        'teacherUid': data['teacherUid'] ?? '',
        'teacherName': data['teacherName'] ?? '',
        'startMinute': data['startMinute'] ?? 0,
        'endMinute': data['endMinute'] ?? 0,
        'room': data['room'],
        'dayOfWeek': data['dayOfWeek'] ?? todayDow,
        'status': data['status'] ?? 'active',
      });
    }
  }

  slots.sort((a, b) =>
      (a['startMinute'] as int).compareTo(b['startMinute'] as int));
  return slots;
});

/// Week's timetable slots grouped by dayOfWeek (1=Mon..7=Sun).
/// Student: own class. Teacher: all assigned classes.
final weekSlotsProvider =
    FutureProvider<Map<int, List<Map<String, dynamic>>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return {};

  final db = FirebaseFirestore.instance;
  final Map<int, List<Map<String, dynamic>>> grouped = {};

  final classIds = appUser.isStudent
      ? [if (appUser.classId != null) appUser.classId!]
      : (appUser.teacherClassIds ?? []);

  for (final classId in classIds) {
    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('timetableSlots')
        .orderBy('dayOfWeek')
        .orderBy('startMinute')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final dow = (data['dayOfWeek'] as int?) ?? 1;
      final slot = {
        'classId': classId,
        'slotId': doc.id,
        'subjectId': data['subjectId'] ?? '',
        'subjectName': data['subjectName'] ?? data['subjectId'] ?? '',
        'teacherUid': data['teacherUid'] ?? '',
        'teacherName': data['teacherName'] ?? '',
        'startMinute': data['startMinute'] ?? 0,
        'endMinute': data['endMinute'] ?? 0,
        'room': data['room'],
        'dayOfWeek': dow,
        'status': data['status'] ?? 'active',
      };
      grouped.putIfAbsent(dow, () => []).add(slot);
    }
  }

  // Sort each day's slots by startMinute
  for (final day in grouped.keys) {
    grouped[day]!.sort((a, b) =>
        (a['startMinute'] as int).compareTo(b['startMinute'] as int));
  }

  return grouped;
});

/// Day name in French from weekday number.
String dayName(int dayOfWeek) {
  const names = {
    1: 'Lundi',
    2: 'Mardi',
    3: 'Mercredi',
    4: 'Jeudi',
    5: 'Vendredi',
    6: 'Samedi',
    7: 'Dimanche',
  };
  return names[dayOfWeek] ?? '';
}

/// Format minutes since midnight to HH:MM string.
String formatTime(int totalMinutes) {
  final h = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final m = (totalMinutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// Creates a timetable slot directly in Firestore.
Future<Map<String, dynamic>> callCreateSlot({
  required String classId,
  required String subjectId,
  required String subjectName,
  required int dayOfWeek,
  required int startMinute,
  required int endMinute,
  String? room,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Authentification requise.');

  // Get teacher name from user doc
  final userSnap = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
  final teacherName = userSnap.data()?['fullName'] ?? '';

  final ref = await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('timetableSlots')
      .add({
    'subjectId': subjectId,
    'subjectName': subjectName,
    'teacherUid': user.uid,
    'teacherName': teacherName,
    'dayOfWeek': dayOfWeek,
    'startMinute': startMinute,
    'endMinute': endMinute,
    'room': room,
    'status': 'active',
    'createdAt': FieldValue.serverTimestamp(),
  });

  return {'slotId': ref.id};
}

/// Cancels a timetable slot (sets status to 'canceled').
Future<void> callCancelSlot({
  required String classId,
  required String slotId,
}) async {
  await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('timetableSlots')
      .doc(slotId)
      .update({
    'status': 'canceled',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// Restores a canceled timetable slot (sets status back to 'active').
Future<void> callRestoreSlot({
  required String classId,
  required String slotId,
}) async {
  await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('timetableSlots')
      .doc(slotId)
      .update({
    'status': 'active',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
