import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/firebase/live_notification_service.dart';
import '../../data/firebase/notification_service.dart';
import '../auth/auth_providers.dart';

/// Singleton provider for NotificationService (FCM token management).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Singleton provider for LiveNotificationService (local notifications).
final liveNotificationServiceProvider =
    Provider<LiveNotificationService>((ref) {
  return LiveNotificationService();
});

/// Provider that initializes FCM when user is logged in.
/// Watch this provider in the main app widget to trigger initialization.
final notificationInitProvider = FutureProvider<void>((ref) async {
  final appUser = ref.watch(appUserProvider).valueOrNull;
  if (appUser == null) {
    // User logged out — stop listeners
    ref.read(liveNotificationServiceProvider).stopListening();
    return;
  }

  // Initialize FCM (token registration + permissions)
  final notificationService = ref.read(notificationServiceProvider);
  await notificationService.initialize();
  notificationService.setupForegroundHandling();

  // Initialize local notifications and start Firestore listeners
  final liveService = ref.read(liveNotificationServiceProvider);
  await liveService.initialize();
  liveService.startListening(appUser);
});
