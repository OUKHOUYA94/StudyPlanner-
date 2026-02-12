import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a user document from Firestore `users/{uid}`.
class AppUser {
  final String uid;
  final String role; // "student" | "teacher"
  final String fullName;
  final String personalNumber;
  final String? classId; // student only
  final List<String>? teacherClassIds; // teacher only
  final String email;
  final String? photoURL;
  final Timestamp createdAt;
  final Timestamp updatedAt;

  const AppUser({
    required this.uid,
    required this.role,
    required this.fullName,
    required this.personalNumber,
    this.classId,
    this.teacherClassIds,
    required this.email,
    this.photoURL,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isStudent => role == 'student';
  bool get isTeacher => role == 'teacher';

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      role: data['role'] as String,
      fullName: data['fullName'] as String,
      personalNumber: data['personalNumber'] as String,
      classId: data['classId'] as String?,
      teacherClassIds: (data['teacherClassIds'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      email: data['email'] as String,
      photoURL: data['photoURL'] as String?,
      createdAt: data['createdAt'] as Timestamp,
      updatedAt: data['updatedAt'] as Timestamp,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'role': role,
      'fullName': fullName,
      'personalNumber': personalNumber,
      if (classId != null) 'classId': classId,
      if (teacherClassIds != null) 'teacherClassIds': teacherClassIds,
      'email': email,
      'photoURL': photoURL,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
