import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Handles FCM setup, permissions, and device token registration.
class NotificationService {
  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Initialize FCM: request permissions and register device token.
  Future<void> initialize() async {
    // Request permission (required for iOS, optional but recommended for Android 13+)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('FCM: Permission granted');
      await _registerToken();
      _listenForTokenRefresh();
    } else {
      debugPrint('FCM: Permission denied');
    }
  }

  /// Register current FCM token to Firestore.
  Future<void> _registerToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveToken(user.uid, token);
        debugPrint('FCM: Token registered');
      }
    } catch (e) {
      debugPrint('FCM: Error getting token: $e');
    }
  }

  /// Listen for token refresh and update Firestore.
  void _listenForTokenRefresh() {
    _messaging.onTokenRefresh.listen((newToken) async {
      final user = _auth.currentUser;
      if (user != null) {
        await _saveToken(user.uid, newToken);
        debugPrint('FCM: Token refreshed');
      }
    });
  }

  /// Save token to Firestore under users/{uid}/devices/{token}.
  Future<void> _saveToken(String uid, String token) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(token)
        .set({
      'token': token,
      'platform': defaultTargetPlatform.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Remove current device token from Firestore (call on logout).
  Future<void> removeToken() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('devices')
            .doc(token)
            .delete();
        debugPrint('FCM: Token removed');
      }
    } catch (e) {
      debugPrint('FCM: Error removing token: $e');
    }
  }

  /// Configure foreground message handling.
  void setupForegroundHandling() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM: Foreground message: ${message.notification?.title}');
      // In a real app, you might show a local notification or in-app alert here
    });
  }

  /// Handle notification tap when app is in background/terminated.
  void setupBackgroundHandling(void Function(RemoteMessage) onMessageTap) {
    // When app is opened from terminated state via notification
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        onMessageTap(message);
      }
    });

    // When app is in background and notification is tapped
    FirebaseMessaging.onMessageOpenedApp.listen(onMessageTap);
  }
}
