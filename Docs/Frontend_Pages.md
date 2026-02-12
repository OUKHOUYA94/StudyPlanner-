# Frontend Pages (Flutter)

## Overview
This document tracks UI pages, routes, and key components for the Firebase-based app.

---

## Navigation
### Bottom navigation (implemented in app_scaffold.dart)
- Accueil -> `/` (home_page.dart)
- Presences -> `/attendance` (attendance_page.dart)
- Examens -> `/assessments` (assessments_page.dart)
- Messages -> `/messages` (messages_page.dart)

### Drawer menu (implemented in app_scaffold.dart)
- Accueil -> `/`
- Emploi du temps -> `/schedule` (schedule_page.dart) -- added session-017
- Matieres -> `/subjects` (subjects_page.dart) -- added session-011
- Etudiants -> `/students` (students_page.dart) -- added session-018 (teacher only)
- Parametres -> `/settings` (settings_page.dart)
- Deconnexion -> implemented (calls AuthService.signOut)

---

## Pages
### Auth (implemented in session-004)
- Connexion -> `/login` (login_page.dart) -- email + password, French error messages
- Mot de passe oublie (optional, not yet implemented)

### Student
- Accueil (implemented in session-009):
  - Greeting: "Bonjour, {firstName}" + role label
  - "Seances d'aujourd'hui" card (time + subject + class + room)
  - "Examens d'aujourd'hui" card (time + title + type + class)
- Emploi du temps (implemented in session-017):
  - Tab "Aujourd'hui": today's slots with time, subject, class, room
  - Tab "Cette semaine": grouped by day (Lundi-Vendredi) with French headers
- Examens (implemented in session-009):
  - "Aujourd'hui" tab with assessment cards
  - "Cette semaine" tab grouped by day with French headers
- Scanner QR (implemented in session-008):
  - "Scanner QR" button on Presences tab
  - Camera scanner with QR-only filter (qr_scanner_page.dart)
  - Submits via submitAttendance Cloud Function
  - Success: "Presence enregistree a HH:MM"
  - Error states: expired, already scanned, invalid token, not in class
- Messages (implemented in session-012):
  - Messages home: class chat entry + subject chats list
  - Chat thread: realtime stream, send message, auto-scroll
  - Message bubbles with sender name, role, timestamp
- Parametres (implemented in session-014):
  - Profile photo with camera edit button (upload to Storage)
  - Immutable fields: fullName, personalNumber, role, class
  - Email field with edit button (reauth flow)
  - Logout button with confirmation

### Teacher
- Accueil (implemented in session-009): same as student but shows all assigned classes
- Emploi du temps (implemented in session-017): same as student for assigned classes
- Etudiants (implemented in session-018):
  - Class selector dropdown (for multi-class teachers)
  - Student list: avatar, fullName, personalNumber, sorted alphabetically
- Presences (implemented in session-007):
  - Session dropdown (today's slots for teacher)
  - "Ouvrir QR (3 min)" button (disabled until selection)
  - QR display page (qr_display_page.dart): QR code + countdown + live scan count
- Examens (implemented in session-010):
  - Same tabs as student (today/week) with assessment cards
  - FAB to create new assessment (opens AssessmentFormPage)
  - Edit/Cancel buttons on each non-canceled card
  - Cancel confirmation dialog
  - Assessment form: class selector, subject (from timetable), title, type, date/time pickers
- Messages (implemented in session-012):
  - Same as student but shows all assigned classes
  - Subject chats filtered to only taught subjects
- Parametres (implemented in session-014): same as student but shows all assigned classes

---

## Shared Components
- AppScaffold (implemented: lib/shared/widgets/app_scaffold.dart)
- SectionCard (planned)
- PrimaryButton (planned)
- Badge (planned)
- NotificationTile (planned)
- ConfirmDialog (planned)

## Router
- Framework: go_router (lib/app/router.dart)
- State management: Riverpod (routerProvider)
- ShellRoute wraps 4 main tabs with shared AppScaffold
- Subjects is outside shell (full-page with own AppBar) -- added session-011
- Schedule is outside shell (full-page with own AppBar) -- added session-017
- Students is outside shell (full-page with own AppBar) -- added session-018
- Settings is outside shell (full-page with own AppBar)
- Auth guard: unauthenticated redirects to /login; authenticated on /login redirects to /
- Refresh on auth state change via _RouterRefreshNotifier

## Auth Architecture
- AppUser model: lib/domain/models/app_user.dart
- AuthService: lib/data/firebase/auth_service.dart (signIn, signOut, fetchUserProfile)
- Providers: lib/features/auth/auth_providers.dart
  - authServiceProvider (AuthService singleton)
  - authStateProvider (StreamProvider<User?>)
  - appUserProvider (FutureProvider<AppUser?> -- fetches Firestore profile)

## Attendance Architecture
- Providers: lib/features/attendance/attendance_providers.dart
  - teacherTodaySlotsProvider (FutureProvider -- today's slots for teacher)
  - callCreateAttendanceSession() (calls Cloud Function)
  - callSubmitAttendance() (calls Cloud Function -- session-008)
  - attendanceRecordsCountStream() (live scan count)
  - fetchClassStudentCount() (total students in class)
  - fetchClassStudents(classId) (fetches student UIDs from members + user profiles -- session-013)
  - attendanceRecordsStream(classId, sessionId) (streams record UIDs with checkedAt timestamps -- session-013)
- QR Scanner: lib/features/attendance/qr_scanner_page.dart
  - Camera scanner (mobile_scanner 7.x, QR-only)
  - States: scanning -> submitting -> success / error
  - JSON payload parsing {classId, sessionId, token}
  - French error mapping for all Cloud Function error codes
- QR Display: lib/features/attendance/qr_display_page.dart
  - Shows QR with JSON payload {classId, sessionId, token}
  - Countdown timer from expiresAt
  - Live stream of scanned count vs total
  - "Voir la liste" button navigates to AttendanceListPage (session-013)
- Attendance List: lib/features/attendance/attendance_list_page.dart (session-013)
  - Teacher view of present/absent students for a session
  - Summary bar: "Présents" count (green check), "Absents" count (red X)
  - Present section: student cards with name + personalNumber + check-in time (HH:MM)
  - Absent section: student cards with name + personalNumber
  - Both sections sorted alphabetically by fullName

## Schedule Architecture
- Providers: lib/features/schedule/schedule_providers.dart
  - todaySlotsProvider (FutureProvider -- today's slots for current user)
  - weekSlotsProvider (FutureProvider -- week slots grouped by dayOfWeek)
  - dayName() (French day name from weekday number)
  - formatTime() (minutes to HH:MM)

## Assessments Architecture
- Providers: lib/features/assessments/assessments_providers.dart
  - todayAssessmentsProvider (FutureProvider -- today's assessments)
  - weekAssessmentsProvider (FutureProvider -- week assessments grouped by date)
  - callCreateAssessment() (calls Cloud Function -- session-010)
  - callUpdateAssessment() (calls Cloud Function -- session-010)
  - callCancelAssessment() (calls Cloud Function -- session-010)
  - assessmentTypeLabel() (French type labels)
  - statusLabel() (French status labels)
- Form: lib/features/assessments/assessment_form_page.dart
  - Create/Edit modes (pass assessment map for edit)
  - Class selector, subject from timetable, title, type dropdown, date/time pickers
  - Returns true on successful submit for provider invalidation
- Cloud Functions: functions/src/assessments.ts
  - createAssessment: teacher auth, class access, ISO week max 3 enforcement
  - updateAssessment: teacher auth, update allowed fields, re-check weekly limit on date change
  - cancelAssessment: teacher auth, set status to "canceled" with optional reason

## Schedule Architecture (Session 017)
- Page: lib/features/schedule/schedule_page.dart
  - Tab "Aujourd'hui": today's slots as cards (time block + subject + class + room)
  - Tab "Cette semaine": grouped by day with French headers (Lundi-Vendredi)
  - Uses existing todaySlotsProvider and weekSlotsProvider
  - Empty states for no slots

## Students Architecture (Session 018)
- Providers: lib/features/students/students_providers.dart
  - classStudentsProvider(classId) (FutureProvider.family -- students with profiles)
  - teacherClassesProvider (FutureProvider -- teacher's classes with student counts)
- Page: lib/features/students/students_page.dart
  - Class selector dropdown (for multi-class teachers)
  - Student list: avatar, fullName, personalNumber, numbered index
  - Alphabetically sorted
  - Teacher-only (drawer hidden for students)

## Subjects Architecture (Sessions 011, 019)
- Providers: lib/features/subjects/subjects_providers.dart
  - subjectsProvider (FutureProvider -- role-aware subject list with teacherName)
    - Student: all subjects from own class
    - Teacher: only subjects they teach (filtered by teacherUid)
  - subjectScheduleProvider(classId, subjectId) (FutureProvider.family -- subject timetable slots)
- Page: lib/features/subjects/subjects_page.dart
  - Subject cards with icon, name, teacher name, chat icon
  - Grouped by class for teacher multi-class view
  - Tap card -> SubjectDetailPage; tap chat icon -> ChatPage
- Detail: lib/features/subjects/subject_detail_page.dart (session-019)
  - Subject info card (name, class, teacher)
  - Weekly schedule for this subject (day + time + room)
  - "Ouvrir le chat" button

## Messaging Architecture
- Providers: lib/features/messages/messages_providers.dart
  - classChatMessagesProvider(classId) (StreamProvider -- realtime class chat messages)
  - subjectChatMessagesProvider(classId, subjectId) (StreamProvider -- realtime subject chat)
  - sendClassChatMessage() (writes to classes/{classId}/classChat)
  - sendSubjectChatMessage() (writes to classes/{classId}/subjectChats/{subjectId}/messages)
  - chatClassIdsProvider (FutureProvider -- user's class IDs for chat selection)
- Messages home: lib/features/messages/messages_page.dart
  - Class chat entry card + subject chats list per class
  - Grouped by class for teacher multi-class view
- Chat thread: lib/features/messages/chat_page.dart
  - Reusable for class chat (subjectId=null) and subject chat
  - Realtime stream, auto-scroll, message bubbles (own=right, other=left)
  - Sender name + role label, timestamp, multiline input

## Settings Architecture
- Providers: lib/features/settings/settings_providers.dart
  - pickAndUploadProfilePhoto() (picks image, uploads to Storage, updates Firestore)
  - updateEmail() (reauth + verifyBeforeUpdateEmail)
  - syncEmailToFirestore() (syncs verified email to Firestore)
  - fetchClassName(classId) (gets class name for display)
  - fetchTeacherClassNames(classIds) (gets multiple class names)
- Page: lib/features/settings/settings_page.dart
  - Profile photo avatar with camera edit button
  - Immutable info card (fullName, personalNumber, role, class/classes)
  - Email with edit button (opens reauth dialog)
  - Logout button with confirmation dialog
- Storage: /users/{uid}/profile.{ext}
  - Max 5MB, image/* content type
  - User can read/write own photo only

## Notifications Architecture (Session 016)
- Service: lib/data/firebase/notification_service.dart
  - initialize() (request permission, register token)
  - removeToken() (called on logout)
  - setupForegroundHandling() (log foreground messages)
  - setupBackgroundHandling() (handle notification taps)
- Providers: lib/features/notifications/notification_providers.dart
  - notificationServiceProvider (singleton NotificationService)
  - notificationInitProvider (FutureProvider -- initializes FCM when user logs in)
- Token Storage: users/{uid}/devices/{token}
  - Fields: token, platform, createdAt, updatedAt
- Cloud Functions Triggers:
  - onAssessmentCreated: notifies class members of new assessment
  - onAssessmentUpdated: notifies class members of canceled/rescheduled assessment

## Theme
- File: lib/app/theme.dart
- AppColors: primary #10437A, secondary #E1A626, background #F6F8FC
- AppCardStyles: 16px border radius, soft shadow
- buildAppTheme(): Material3 ThemeData

---

## Notes
Update this file when pages/routes/components change.
