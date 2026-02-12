import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../domain/models/app_user.dart';

/// Android notification channel.
const _channelId = 'study_planner_default';
const _channelName = 'Study Planner';
const _channelDesc = 'Notifications de Study Planner';

/// Notification IDs (auto-increment per category).
int _nextId = 1000;

/// Listens to Firestore streams and shows local notifications for:
/// - New chat messages (class chat + subject chats)
/// - New assessments
/// - New timetable slots
/// - Canceled / restored timetable slots
class LiveNotificationService {
  final FlutterLocalNotificationsPlugin _plugin;
  final FirebaseFirestore _db;

  final List<StreamSubscription> _subscriptions = [];
  bool _initialized = false;

  LiveNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    FirebaseFirestore? db,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _db = db ?? FirebaseFirestore.instance;

  /// Initialize the local notifications plugin.
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Create notification channel
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  /// Start listening for real-time changes relevant to [user].
  void startListening(AppUser user) {
    stopListening();

    final classIds = user.isStudent
        ? [if (user.classId != null) user.classId!]
        : (user.teacherClassIds ?? []);

    if (classIds.isEmpty) return;

    final now = Timestamp.now();

    for (final classId in classIds) {
      // ── Chat messages ──
      if (user.isStudent) {
        _listenClassChat(classId, user.uid, now);
      }
      _listenSubjectChats(classId, user.uid, now);

      // ── Assessments ──
      _listenAssessments(classId, now);

      // ── Timetable slots ──
      _listenTimetableSlots(classId, now);
    }

    debugPrint('LiveNotif: Started listening for ${classIds.length} class(es)');
  }

  /// Stop all listeners.
  void stopListening() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  // ── Class chat ─────────────────────────────────────────────────────

  void _listenClassChat(String classId, String myUid, Timestamp since) {
    final sub = _db
        .collection('classes')
        .doc(classId)
        .collection('classChat')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;
        final senderUid = data['senderUid'] as String? ?? '';
        if (senderUid == myUid) continue; // skip own messages

        final senderName = data['senderName'] as String? ?? 'Quelqu\'un';
        final text = data['text'] as String? ?? '';

        _show(
          title: 'Chat de classe \u2022 $classId',
          body: '$senderName: $text',
        );
      }
    }, onError: (e) => debugPrint('LiveNotif classChat error: $e'));

    _subscriptions.add(sub);
  }

  // ── Subject chats ──────────────────────────────────────────────────

  void _listenSubjectChats(String classId, String myUid, Timestamp since) {
    // First get subjects in this class, then listen to each
    _db
        .collection('classes')
        .doc(classId)
        .collection('subjects')
        .get()
        .then((subjectsSnap) {
      for (final subjectDoc in subjectsSnap.docs) {
        final subjectName = subjectDoc.data()['name'] as String? ?? subjectDoc.id;
        final subjectId = subjectDoc.id;

        final sub = _db
            .collection('classes')
            .doc(classId)
            .collection('subjectChats')
            .doc(subjectId)
            .collection('messages')
            .where('createdAt', isGreaterThan: since)
            .orderBy('createdAt')
            .snapshots()
            .listen((snap) {
          for (final change in snap.docChanges) {
            if (change.type != DocumentChangeType.added) continue;
            final data = change.doc.data();
            if (data == null) continue;
            final senderUid = data['senderUid'] as String? ?? '';
            if (senderUid == myUid) continue;

            final senderName = data['senderName'] as String? ?? 'Quelqu\'un';
            final text = data['text'] as String? ?? '';

            _show(
              title: '$subjectName \u2022 $classId',
              body: '$senderName: $text',
            );
          }
        }, onError: (e) => debugPrint('LiveNotif subjectChat error: $e'));

        _subscriptions.add(sub);
      }
    }).catchError((e) {
      debugPrint('LiveNotif subjects fetch error: $e');
    });
  }

  // ── Assessments ────────────────────────────────────────────────────

  void _listenAssessments(String classId, Timestamp since) {
    final sub = _db
        .collection('classes')
        .doc(classId)
        .collection('assessments')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null) continue;

        final title = data['title'] as String? ?? 'Examen';
        final type = _assessmentTypeLabel(data['type'] as String? ?? '');
        final dateTime = data['dateTime'] as Timestamp?;
        final dateStr = dateTime != null ? _formatDate(dateTime) : '';

        _show(
          title: 'Nouvel examen \u2022 $classId',
          body: '$type: $title${dateStr.isNotEmpty ? ' \u2022 $dateStr' : ''}',
        );
      }
    }, onError: (e) => debugPrint('LiveNotif assessments error: $e'));

    _subscriptions.add(sub);
  }

  // ── Timetable slots ────────────────────────────────────────────────

  void _listenTimetableSlots(String classId, Timestamp since) {
    // Listen for new slots AND status changes (cancel/restore)
    final sub = _db
        .collection('classes')
        .doc(classId)
        .collection('timetableSlots')
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final subjectName = data['subjectName'] as String? ??
            data['subjectId'] as String? ??
            'S\u00e9ance';
        final dayName = _dayName(data['dayOfWeek'] as int? ?? 1);
        final status = data['status'] as String? ?? 'active';

        if (change.type == DocumentChangeType.added) {
          // Only notify for slots created after the listener started
          final createdAt = data['createdAt'] as Timestamp?;
          if (createdAt != null && createdAt.compareTo(since) > 0) {
            _show(
              title: 'Nouvelle s\u00e9ance \u2022 $classId',
              body: '$subjectName \u2022 $dayName',
            );
          }
        } else if (change.type == DocumentChangeType.modified) {
          final updatedAt = data['updatedAt'] as Timestamp?;
          if (updatedAt != null && updatedAt.compareTo(since) > 0) {
            if (status == 'canceled') {
              _show(
                title: 'S\u00e9ance annul\u00e9e \u2022 $classId',
                body: '$subjectName \u2022 $dayName',
              );
            } else if (status == 'active') {
              _show(
                title: 'S\u00e9ance r\u00e9tablie \u2022 $classId',
                body: '$subjectName \u2022 $dayName',
              );
            }
          }
        }
      }
    }, onError: (e) => debugPrint('LiveNotif timetable error: $e'));

    _subscriptions.add(sub);
  }

  // ── Show notification ──────────────────────────────────────────────

  Future<void> _show({required String title, required String body}) async {
    if (!_initialized) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const details = NotificationDetails(android: androidDetails);

    await _plugin.show(_nextId++, title, body, details);
  }

  // ── Helpers ────────────────────────────────────────────────────────

  String _assessmentTypeLabel(String type) {
    switch (type) {
      case 'exam':
        return 'Examen';
      case 'ds':
        return 'Devoir Surveill\u00e9';
      case 'quiz':
        return 'Quiz';
      case 'tp':
        return 'TP';
      case 'project':
        return 'Projet';
      default:
        return type;
    }
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    const months = [
      '', 'Jan', 'F\u00e9v', 'Mar', 'Avr', 'Mai', 'Juin',
      'Juil', 'Ao\u00fb', 'Sep', 'Oct', 'Nov', 'D\u00e9c',
    ];
    return '${d.day} ${months[d.month]}';
  }

  String _dayName(int dow) {
    const days = [
      '', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi',
    ];
    return dow >= 1 && dow <= 6 ? days[dow] : 'Jour $dow';
  }
}
