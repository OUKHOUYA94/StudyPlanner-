import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

/// Picks an image from gallery, converts to base64, and stores
/// directly in Firestore (no Firebase Storage / billing needed).
/// Returns the data URI on success, null on cancel/error.
Future<String?> pickAndUploadProfilePhoto() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 256,
    maxHeight: 256,
    imageQuality: 60,
  );

  if (image == null) return null;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final bytes = await image.readAsBytes();
  final ext = image.path.split('.').last.toLowerCase();
  final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
  final dataUri = 'data:$mimeType;base64,${base64Encode(bytes)}';

  // Store directly in Firestore
  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
    'photoURL': dataUri,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  return dataUri;
}

/// Updates the user's email in Firebase Auth and Firestore.
/// Requires reauthentication with current password.
/// Throws FirebaseAuthException on failure.
Future<void> updateEmail({
  required String newEmail,
  required String currentPassword,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null || user.email == null) {
    throw Exception('Utilisateur non connecté');
  }

  // Reauthenticate
  final credential = EmailAuthProvider.credential(
    email: user.email!,
    password: currentPassword,
  );
  await user.reauthenticateWithCredential(credential);

  // Update Auth email (sends verification email)
  await user.verifyBeforeUpdateEmail(newEmail.trim());

  // Note: Firestore email field will be updated after email verification
  // For now, we don't update Firestore since the new email isn't verified yet
}

/// Updates the user's email in Firestore after verification.
/// Called when the user confirms their email has been verified.
Future<void> syncEmailToFirestore() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  // Reload to get latest email verification status
  await user.reload();
  final refreshedUser = FirebaseAuth.instance.currentUser;
  if (refreshedUser == null) return;

  await FirebaseFirestore.instance
      .collection('users')
      .doc(refreshedUser.uid)
      .update({
    'email': refreshedUser.email,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

/// Fetches the class name for a student.
Future<String?> fetchClassName(String classId) async {
  final doc =
      await FirebaseFirestore.instance.collection('classes').doc(classId).get();
  if (!doc.exists) return null;
  return doc.data()?['name'] as String?;
}

/// Fetches class names for a teacher's assigned classes.
Future<List<String>> fetchTeacherClassNames(List<String> classIds) async {
  final names = <String>[];
  for (final classId in classIds) {
    final name = await fetchClassName(classId);
    if (name != null) names.add(name);
  }
  return names;
}
