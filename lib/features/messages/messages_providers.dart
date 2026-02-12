import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';

final _db = FirebaseFirestore.instance;

/// Streams class chat messages.
/// Path: classes/{classId}/classChat/{messageId}
final classChatMessagesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>(
        (ref, classId) {
  return _db
      .collection('classes')
      .doc(classId)
      .collection('classChat')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {
              'messageId': doc.id,
              'senderUid': data['senderUid'] ?? '',
              'senderName': data['senderName'] ?? '',
              'senderRole': data['senderRole'] ?? '',
              'text': data['text'] ?? '',
              'createdAt': data['createdAt'] as Timestamp?,
            };
          }).toList());
});

/// Streams subject chat messages.
/// Path: classes/{classId}/subjectChats/{subjectId}/messages/{messageId}
final subjectChatMessagesProvider = StreamProvider.family<
    List<Map<String, dynamic>>,
    ({String classId, String subjectId})>((ref, params) {
  return _db
      .collection('classes')
      .doc(params.classId)
      .collection('subjectChats')
      .doc(params.subjectId)
      .collection('messages')
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) => snap.docs.map((doc) {
            final data = doc.data();
            return {
              'messageId': doc.id,
              'senderUid': data['senderUid'] ?? '',
              'senderName': data['senderName'] ?? '',
              'senderRole': data['senderRole'] ?? '',
              'text': data['text'] ?? '',
              'createdAt': data['createdAt'] as Timestamp?,
            };
          }).toList());
});

/// Sends a message to class chat.
Future<void> sendClassChatMessage({
  required String classId,
  required String senderUid,
  required String senderName,
  required String senderRole,
  required String text,
}) async {
  await _db
      .collection('classes')
      .doc(classId)
      .collection('classChat')
      .add({
    'senderUid': senderUid,
    'senderName': senderName,
    'senderRole': senderRole,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Sends a message to a subject chat.
Future<void> sendSubjectChatMessage({
  required String classId,
  required String subjectId,
  required String senderUid,
  required String senderName,
  required String senderRole,
  required String text,
}) async {
  await _db
      .collection('classes')
      .doc(classId)
      .collection('subjectChats')
      .doc(subjectId)
      .collection('messages')
      .add({
    'senderUid': senderUid,
    'senderName': senderName,
    'senderRole': senderRole,
    'text': text,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Provides the list of classes for chat selection.
/// Student: own class. Teacher: all assigned classes.
final chatClassIdsProvider = FutureProvider<List<String>>((ref) async {
  final appUser = await ref.watch(appUserProvider.future);
  if (appUser == null) return [];

  if (appUser.isStudent) {
    return appUser.classId != null ? [appUser.classId!] : [];
  }
  return appUser.teacherClassIds ?? [];
});
