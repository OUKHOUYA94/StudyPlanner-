# QA Checklist

## Pre-Deployment Verification

### Build Verification
- [ ] `flutter analyze` - 0 issues
- [ ] `flutter test` - all tests pass
- [ ] `cd functions && npm run build` - tsc 0 errors
- [ ] Android debug build succeeds: `flutter build apk --debug`
- [ ] Android release build succeeds: `flutter build apk --release`

### Firebase Configuration
- [ ] `google-services.json` placed in `android/app/`
- [ ] Firebase project created in Firebase Console
- [ ] Authentication enabled (Email/Password)
- [ ] Firestore database created
- [ ] Storage bucket created
- [ ] Cloud Functions deployed

---

## Feature Acceptance Tests

### Authentication (Session 004)
- [ ] Login with valid email/password works
- [ ] Login with invalid credentials shows French error
- [ ] Logout works from drawer menu
- [ ] Logout works from Settings page
- [ ] Auth state persists across app restart

### Navigation (Session 003)
- [ ] Bottom nav: Accueil, Présences, Examens, Messages
- [ ] Drawer menu opens with hamburger icon
- [ ] Drawer: Accueil, Matières, Paramètres, Déconnexion
- [ ] Tab switching works correctly
- [ ] Back navigation behaves correctly

### Home / Accueil (Session 009)
- [ ] Greeting shows "Bonjour, {firstName}"
- [ ] Role label shows (Étudiant/Enseignant)
- [ ] Today's schedule slots displayed
- [ ] Today's assessments displayed
- [ ] Empty states show appropriate messages

### Attendance - Teacher (Sessions 007, 013)
- [ ] Teacher sees session dropdown with today's slots
- [ ] "Ouvrir QR (3 min)" button works
- [ ] QR code displays with countdown timer
- [ ] Live scan count updates in realtime
- [ ] "Voir la liste" button navigates to attendance list
- [ ] Present/absent summary displays correctly
- [ ] Student names and check-in times show

### Attendance - Student (Session 008)
- [ ] "Scanner QR" button appears for students
- [ ] Camera scanner opens
- [ ] Valid QR scan submits attendance
- [ ] Success message shows with time
- [ ] Error messages in French (expired, already scanned, etc.)

### Assessments - View (Session 009)
- [ ] "Aujourd'hui" tab shows today's assessments
- [ ] "Cette semaine" tab shows week assessments
- [ ] Assessment cards show: subject, title, type, date/time, status
- [ ] Assessments grouped by day with French headers

### Assessments - CRUD (Session 010)
- [ ] Teacher sees FAB to create assessment
- [ ] Create form: class selector, subject, title, type, date/time
- [ ] Edit button on assessment cards works
- [ ] Cancel button shows confirmation dialog
- [ ] Max 3 per ISO week enforced (error message)
- [ ] Changes reflect immediately after submit

### Subjects / Matières (Session 011)
- [ ] Subject list shows all 6 subjects
- [ ] Teacher sees only taught subjects
- [ ] Subject cards show name and icon
- [ ] Tap navigates to subject chat

### Messaging (Session 012)
- [ ] Class chat entry shown
- [ ] Subject chat entries shown
- [ ] Messages stream in realtime
- [ ] Own messages right-aligned (blue)
- [ ] Other messages left-aligned (white)
- [ ] Sender name and role shown
- [ ] Timestamps display correctly
- [ ] Send message works
- [ ] Empty state shows "Écrivez le premier message !"

### Settings / Paramètres (Session 014)
- [ ] Profile photo displays (or initial)
- [ ] Camera button allows photo upload
- [ ] Immutable fields shown: name, ID, role, class
- [ ] Email field with edit button
- [ ] Email change requires current password
- [ ] Logout button with confirmation
- [ ] Photo uploads to Storage successfully

### Notifications (Session 016)
- [ ] FCM permission requested on first launch
- [ ] Device token stored in Firestore
- [ ] Push notification received for new assessment
- [ ] Push notification received for canceled assessment
- [ ] Push notification received for rescheduled assessment
- [ ] Token removed on logout

---

## Security Rules Verification

### Firestore Rules
- [ ] Users can only read own profile
- [ ] Users can only update photoURL, email
- [ ] Class members can read class data
- [ ] Non-members cannot read class data
- [ ] Chat messages require correct senderUid
- [ ] Chat messages require serverTimestamp
- [ ] Device tokens scoped to own user

### Storage Rules
- [ ] Users can upload own profile photo
- [ ] Upload limited to 5MB
- [ ] Upload limited to image/* content type
- [ ] Users cannot access other users' photos

---

## Performance Checks
- [ ] App launches within 3 seconds
- [ ] Navigation transitions are smooth
- [ ] Lists scroll without jank
- [ ] No memory leaks during extended use
- [ ] Offline behavior graceful (error messages)

---

## Localization
- [ ] All UI text in French
- [ ] Error messages in French
- [ ] Date formats use French locale (dd/MM/yyyy)
- [ ] Day names in French (Lundi, Mardi, etc.)
