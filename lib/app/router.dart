import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/assessments/assessments_page.dart';
import '../features/attendance/attendance_page.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/login_page.dart';
import '../features/home/home_page.dart';
import '../features/messages/messages_page.dart';
import '../features/schedule/schedule_page.dart';
import '../features/settings/settings_page.dart';
import '../features/students/students_page.dart';
import '../features/subjects/subjects_page.dart';
import '../shared/widgets/app_scaffold.dart';

/// Route path constants.
class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String home = '/';
  static const String attendance = '/attendance';
  static const String assessments = '/assessments';
  static const String messages = '/messages';
  static const String subjects = '/subjects';
  static const String schedule = '/schedule';
  static const String students = '/students';
  static const String settings = '/settings';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Router provider (Riverpod) with auth-based redirect.
final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: _RouterRefreshNotifier(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      // Not logged in and not on login page -> go to login.
      if (!isLoggedIn && !isOnLogin) return AppRoutes.login;

      // Logged in but still on login page -> go to home.
      if (isLoggedIn && isOnLogin) return AppRoutes.home;

      return null; // no redirect
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.attendance,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AttendancePage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.assessments,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AssessmentsPage(),
            ),
          ),
          GoRoute(
            path: AppRoutes.messages,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessagesPage(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.subjects,
        builder: (context, state) => const SubjectsPage(),
      ),
      GoRoute(
        path: AppRoutes.schedule,
        builder: (context, state) => const SchedulePage(),
      ),
      GoRoute(
        path: AppRoutes.students,
        builder: (context, state) => const StudentsPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

/// Notifies GoRouter to re-evaluate redirect when auth state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateProvider, (_, _) {
      notifyListeners();
    });
  }
}
