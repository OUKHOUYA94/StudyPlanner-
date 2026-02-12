import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/auth_service.dart';
import '../../domain/models/app_user.dart';

/// Provides the AuthService singleton.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Streams Firebase Auth state (User? — null means signed out).
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Fetches the AppUser profile from Firestore after Firebase Auth login.
/// Returns null if user doc does not exist.
final appUserProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull;
  if (user == null) return null;
  return ref.watch(authServiceProvider).fetchUserProfile(user.uid);
});
