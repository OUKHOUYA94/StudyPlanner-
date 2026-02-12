import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

/// Today's timetable slots for the current teacher across their classes.
/// Returns a list of maps with classId, slotId, and slot data.
final teacherTodaySlotsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null || !appUser.isTeacher) return [];

  final classIds = appUser.teacherClassIds ?? [];
  if (classIds.isEmpty) return [];

  final now = DateTime.now();
  final todayDow = now.weekday; // 1=Mon..7=Sun (matches Firestore)

  final db = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> slots = [];

  for (final classId in classIds) {
    final snap = await db
        .collection('classes')
        .doc(classId)
        .collection('timetableSlots')
        .where('dayOfWeek', isEqualTo: todayDow)
        .where('teacherUid', isEqualTo: appUser.uid)
        .orderBy('startMinute')
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      slots.add({
        'classId': classId,
        'slotId': doc.id,
        'subjectId': data['subjectId'],
        'startMinute': data['startMinute'],
        'endMinute': data['endMinute'],
        'room': data['room'],
      });
    }
  }

  return slots;
});

/// Creates an attendance session directly in Firestore.
/// Generates a random token, stores it in the session doc.
/// Returns { sessionId, token, expiresAt }.
Future<Map<String, dynamic>> callCreateAttendanceSession({
  required String classId,
  required String timetableSlotId,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Authentification requise.');

  final db = FirebaseFirestore.instance;

  // Generate random 64-char hex token
  final random = Random.secure();
  final token = List.generate(32, (_) => random.nextInt(256))
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();

  // 3-minute expiration
  final expiresAt = DateTime.now().add(const Duration(minutes: 3));

  final sessionRef = await db
      .collection('classes')
      .doc(classId)
      .collection('attendanceSessions')
      .add({
    'teacherUid': uid,
    'timetableSlotId': timetableSlotId,
    'startAt': FieldValue.serverTimestamp(),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'status': 'open',
    'token': token,
    'createdAt': FieldValue.serverTimestamp(),
  });

  return {
    'sessionId': sessionRef.id,
    'token': token,
    'expiresAt': expiresAt.toIso8601String(),
  };
}

/// Submits student attendance by writing a record to Firestore.
/// Firestore rules verify the token matches and session hasn't expired.
/// Returns { success: true, checkedAt: string }.
Future<Map<String, dynamic>> callSubmitAttendance({
  required String classId,
  required String sessionId,
  required String token,
}) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) throw Exception('Authentification requise.');

  final db = FirebaseFirestore.instance;
  final recordRef = db
      .collection('classes')
      .doc(classId)
      .collection('attendanceSessions')
      .doc(sessionId)
      .collection('records')
      .doc(uid);

  // Check for duplicate
  final existing = await recordRef.get();
  if (existing.exists) {
    throw Exception('Présence déjà enregistrée.');
  }

  // Write record — Firestore rules enforce token + expiration
  await recordRef.set({
    'present': true,
    'token': token,
    'checkedAt': FieldValue.serverTimestamp(),
    'clientScannedAt': DateTime.now().toIso8601String(),
    'method': 'qr',
  });

  return {
    'success': true,
    'checkedAt': DateTime.now().toIso8601String(),
  };
}

/// Streams the attendance records count for a given session.
Stream<int> attendanceRecordsCountStream({
  required String classId,
  required String sessionId,
}) {
  return FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('attendanceSessions')
      .doc(sessionId)
      .collection('records')
      .snapshots()
      .map((snap) => snap.docs.length);
}

/// Streams the total number of students in a class.
Future<int> fetchClassStudentCount(String classId) async {
  final snap = await FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('members')
      .where('role', isEqualTo: 'student')
      .count()
      .get();
  return snap.count ?? 0;
}

/// Fetches all students in a class with their user profiles.
/// Returns list of { uid, fullName, personalNumber }.
Future<List<Map<String, dynamic>>> fetchClassStudents(String classId) async {
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
      });
    }
  }

  students.sort((a, b) =>
      (a['fullName'] as String).compareTo(b['fullName'] as String));
  return students;
}

/// Streams attendance records for a session.
/// Returns map of { uid: { checkedAt, present } }.
Stream<Map<String, Map<String, dynamic>>> attendanceRecordsStream({
  required String classId,
  required String sessionId,
}) {
  return FirebaseFirestore.instance
      .collection('classes')
      .doc(classId)
      .collection('attendanceSessions')
      .doc(sessionId)
      .collection('records')
      .snapshots()
      .map((snap) {
    final Map<String, Map<String, dynamic>> records = {};
    for (final doc in snap.docs) {
      final data = doc.data();
      records[doc.id] = {
        'checkedAt': data['checkedAt'] as Timestamp?,
        'present': data['present'] ?? true,
      };
    }
    return records;
  });
}
