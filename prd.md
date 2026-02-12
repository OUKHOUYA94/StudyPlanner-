# Product Requirements Document (PRD) — **Study Planner**
**Platform:** Mobile (Android first, iOS optional)  
**App Framework:** Flutter  
**Backend/DB:** Firebase (Auth, Firestore, Cloud Functions, Storage, FCM)  
**UI Language:** French (all screens, labels, messages, notifications)  
**Brand Colors:** Primary `#10437A`, Secondary `#E1A626`  
**Roles (v1):** Student, Teacher (NO Admin)  
**Seeding:** Mandatory — full database + Auth users + demo data + includes “Amine Oukhouya”  
**Email Domain for all seeded accounts:** `@EMG.ma`  

---

## 1) Executive Summary

### 1.1 What we are building
**Study Planner** is a school/engineering-class mobile application that helps **students** and **teachers** manage:
- Class schedule (today & week)
- Assessments (exams/tests/devoirs) (today & week)
- Attendance via **secure QR scanning** (teacher selects a session and opens a QR valid for **3 minutes**)
- Communication via:
  - **Class chat**
  - **Subject chats** (exactly **6 subjects per class**, each subject has **1 teacher**, and its chat includes only **students of that class + that subject’s teacher**)
- Profile settings: login/logout, change photo, change email; identity fields are immutable.

### 1.2 Key constraint (important)
There is **no Admin role**. Therefore, the project must include a **complete Firebase seeding process** that creates:
- All classes, subjects, teachers, students, schedules, assessments
- All Firebase Authentication accounts
- All Firestore documents
- Includes the user “**Amine Oukhouya**” as both:
  - a Student account
  - a Teacher account  
(two separate emails ending with `@EMG.ma`)

---

## 2) Objectives & Success Criteria

### 2.1 Objectives
1. Provide a fast, clear **Today** view for students and teachers.
2. Offer a complete **Weekly view** (schedule and assessments).
3. Provide **tamper-resistant attendance** with:
   - Teacher-controlled QR (3 minutes validity)
   - Server-verified scan time (`checkedAt` server timestamp)
4. Provide structured communication:
   - Class chat
   - Subject chat (6 subjects)
5. Keep identity stable (immutable full name, personal number, class membership).

### 2.2 Success Criteria (acceptance)
- ✅ Seed script runs successfully and populates Firebase Auth + Firestore completely.
- ✅ Students can view schedule & assessments and send chat messages.
- ✅ Teachers can manage assessments and open attendance QR only after selecting a session.
- ✅ Attendance record shows correct **server timestamp** for each student scan.
- ✅ Subject chat access is restricted correctly.
- ✅ UI is professional + creative using the brand colors.

---

## 3) Users & Roles

### 3.1 Roles
- **Student**
- **Teacher**

### 3.2 Permission Matrix (high level)
| Feature | Student | Teacher |
|---|---:|---:|
| View class schedule (today/week) | ✅ | ✅ (for assigned classes) |
| View assessments (today/week) | ✅ | ✅ |
| Create/update/cancel assessments | ❌ | ✅ |
| Class chat (read/send) | ✅ | ✅ |
| Subject chat (read/send) | ✅ | ✅ (only for subjects they teach) |
| Open attendance QR | ❌ | ✅ |
| Scan attendance QR | ✅ | ❌ |
| View attendance list | ❌ | ✅ |
| Change profile photo/email | ✅ | ✅ |
| Change full name/class/personal number | ❌ | ❌ |

---

## 4) Scope (v1)

### 4.1 Included
- Auth: login/logout
- Home with bottom navigation (as per your reference):
  - Accueil, Présences, Examens, Messages
- Schedule: today + week
- Assessments: list today + week; teacher CRUD
- Attendance: QR open (teacher) + scan (student) + live list (teacher)
- Messages: class chat + subject chats
- Settings: photo + email + logout

### 4.2 Excluded (v1)
- Admin dashboard/web panel
- Parents role
- Grading/marks system
- Payment/subscription
- Multi-school multi-tenant configuration (later)

---

## 5) UX / UI Requirements (French)

### 5.1 Branding & Visual Style
- **Professional + creative**
- Background: light `#F6F8FC` with subtle abstract shapes
- Cards: white, rounded 16px, soft shadow
- AppBar: primary `#10437A`
- Secondary `#E1A626`: CTA buttons, badges, countdown, highlights
- Icons: clean outline icons

### 5.2 Navigation (must match your reference)
Bottom bar (same for Student and Teacher):
- **Accueil**
- **Présences**
- **Examens**
- **Messages**

Top-left: **Hamburger menu** (requested)
Menu items:
- Accueil
- Paramètres
- Déconnexion

### 5.3 Screen list (French titles)
- Accueil
- Présences
- Examens
- Messages
- Paramètres
- (Subscreens) Emploi du temps, Modules, Chat de classe, Chat de module, QR Présence, Liste des présences

---

## 6) Key Screens & Detailed Requirements

## 6.1 Authentication
### Screens
- Connexion (Email + Mot de passe)
- (Optional) Mot de passe oublié

### Behaviors
- Successful login routes the user based on `users/{uid}.role`
- Errors shown in French

---

## 6.2 Home — **Accueil**
### Student View (Accueil)
Components:
1. AppBar with hamburger (left), title “Accueil”, avatar (right)
2. Card: **Séances d’aujourd’hui**
   - list sessions (time + module + salle)
3. Card: **Examens d’aujourd’hui**
   - list assessments for today (type badge + module + time)
4. CTA: **Scanner QR** (Secondary #E1A626)

### Teacher View (Accueil) — same style as student
Components:
1. Card: **Séances d’aujourd’hui**
2. Card: **Présences**
   - Dropdown: “Choisir une séance”
   - Button: “Ouvrir QR (3 min)” (disabled until selected)
3. Card: **Examens d’aujourd’hui** (readable list)
4. Quick actions (optional): “Créer un examen”

---

## 6.3 Schedule — **Emploi du temps**
### Student
- Today schedule (auto)
- Week schedule grouped by day

### Teacher
- Today schedule: sessions they teach (across assigned classes)
- Week schedule aggregated

---

## 6.4 Subjects — **Modules** (exactly 6 per class)
Each class has:
- 6 subjects
- 1 teacher per subject
Students see 6 modules; teachers see their taught module(s).

---

## 6.5 Assessments — **Examens / Contrôles / Devoirs**
### Student
- Read-only lists:
  - Aujourd’hui
  - Cette semaine

### Teacher (CRUD)
- Create assessment: module, type, date/time, title
- Update: date/time, title
- Cancel: mark `status=canceled` (optional reason)

**Business rule**
- Max **3 assessments per week per class** (enforced server-side in Cloud Function)

---

## 6.6 Attendance — **Présences** (QR)
### Teacher
1. Choose session from dropdown (today’s sessions)
2. Tap “Ouvrir QR (3 min)”
3. QR screen shows:
   - QR code
   - Countdown “03:00” (gold)
   - Count “Scannés: 12 / 25”
4. Tap “Liste des présences”
   - list students with status: Présent / Absent

### Student
1. Tap “Scanner QR”
2. Scan QR
3. Confirmation:
   - “Présence enregistrée à 10:07”

**Security**
- Student cannot write attendance records directly.
- Token validated on server and expires after 3 minutes.
- One record per student per session.

---

## 6.7 Messaging — **Messages**
### Features
1. **Chat de classe**
   - All students of the class + relevant teachers
2. **Chats des modules**
   - 6 modules list
   - Each module chat: only class students + that module teacher

### Messaging constraints
- `createdAt` must be serverTimestamp
- update/delete messages: disabled (v1) for simplicity

---

## 6.8 Settings — **Paramètres**
Accessible via hamburger menu and/or avatar.

### Allowed changes
- Change profile photo
- Change email
- Logout

### Read-only fields (immutable)
- Nom complet (fullName)
- Numéro personnel (personalNumber)
- Classe (classId for student)

---

## 7) Firebase Architecture (Required)

### 7.1 Firebase Services
- **Authentication**: Email/Password
- **Firestore**: data storage
- **Cloud Functions**: secure logic (attendance + assessment rules)
- **Storage**: profile photos
- **FCM**: notifications (recommended)

---

## 8) Firestore Data Model (Complete)

> Classes IDs: `GI`, `GE`, `GC`.

### 8.1 `users/{uid}`
Fields:
- `role`: `"student" | "teacher"`
- `fullName`: string **immutable**
- `personalNumber`: string **immutable**
- `classId`: string **immutable** (student only)
- `teacherClassIds`: array<string> (teacher only)
- `email`: string (display)
- `photoURL`: string|null (editable)
- `createdAt`: Timestamp
- `updatedAt`: Timestamp

---

### 8.2 `classes/{classId}`
Fields:
- `name`: string
- `teacherUids`: array<string>
- `createdAt`: Timestamp

#### 8.2.1 `classes/{classId}/members/{uid}`
Fields:
- `role`: `"student" | "teacher"`
- `fullName`: string
- `joinedAt`: Timestamp

---

### 8.3 Subjects (6 per class)
`classes/{classId}/subjects/{subjectId}`
Fields:
- `name`: string
- `teacherUid`: string (exactly 1)
- `active`: bool

---

### 8.4 Timetable
`classes/{classId}/timetableSlots/{slotId}`
Fields:
- `dayOfWeek`: number (1=Mon…7=Sun)
- `startMinute`: number
- `endMinute`: number
- `subjectId`: string
- `teacherUid`: string
- `room`: string|null

---

### 8.5 Assessments
`classes/{classId}/assessments/{assessmentId}`
Fields:
- `type`: `"exam" | "test" | "devoir"`
- `title`: string
- `subjectId`: string
- `dateTime`: Timestamp
- `status`: `"active" | "canceled"`
- `createdBy`: teacherUid
- `createdAt`: Timestamp

Indexes (expected):
- `dateTime` + `status`
- `subjectId` + `dateTime`

---

### 8.6 Attendance Sessions (QR)
`classes/{classId}/attendanceSessions/{sessionId}`
Fields:
- `teacherUid`: string
- `timetableSlotId`: string (selected session)
- `startAt`: Timestamp
- `expiresAt`: Timestamp (start + 3 minutes)
- `status`: `"open" | "closed"`
- `tokenHash`: string
- `createdAt`: Timestamp

#### 8.6.1 Attendance Records
`classes/{classId}/attendanceSessions/{sessionId}/records/{studentUid}`
Fields:
- `present`: true
- `checkedAt`: Timestamp (serverTimestamp) ✅ official scan time
- `clientScannedAt`: Timestamp|null (optional)
- `method`: `"qr"`

---

### 8.7 Chat
#### 8.7.1 Class chat
`classes/{classId}/classChat/messages/{messageId}`
Fields:
- `senderUid`
- `senderName`
- `senderRole`
- `text`
- `createdAt` (serverTimestamp)

#### 8.7.2 Subject chat
`classes/{classId}/subjectChats/{subjectId}/messages/{messageId}`
Fields:
- same as class chat

Index:
- `createdAt` descending

---

## 9) Cloud Functions (Detailed)

### 9.1 Attendance (Required)
#### Function: `createAttendanceSession`
**Input**
- `classId`
- `timetableSlotId`

**Validations**
- Caller is teacher
- Teacher has access to `classId`
- `timetableSlotId` exists in today’s timetableSlots and belongs to class
- Creates session with expiresAt = now + 3 minutes

**Output**
- `sessionId`
- `token` (plain, only returned once)
- `expiresAt`

#### Function: `submitAttendance`
**Input**
- `classId`
- `sessionId`
- `token`
- `clientScannedAt` (optional)

**Validations**
- Caller is student
- Student belongs to class
- Session exists, open, not expired
- token hash matches
- record does not already exist

**Writes**
- record with `checkedAt = serverTimestamp()`

---

### 9.2 Assessments (Required)
#### Function: `createAssessment`
**Input**
- classId, subjectId, type, title, dateTime

**Validations**
- Caller is teacher
- Teacher is the teacherUid of subjectId
- Enforce max 3 assessments/week/class

#### Function: `updateAssessment`
- Same validation + update fields

#### Function: `cancelAssessment`
- Sets status=canceled

---

## 10) Security Rules (Implementation Notes)

### 10.1 Users
- Users can read their own doc.
- Users can update only editable fields (photoURL, display email, optional fields).
- Immutable fields must not change.

### 10.2 Class/Subjects
- Students read only their class
- Teachers read only classes in teacherClassIds

### 10.3 Chats
- Class chat:
  - Student in class OR teacher assigned to class
- Subject chat:
  - Student in class OR teacherUid == subject teacherUid

### 10.4 Attendance
- Client cannot write attendance sessions or records.
- Writes happen only via Cloud Functions (Admin SDK bypass).

---

## 11) **Mandatory Seeding (Full Database Build)**

### 11.1 Seed Must Create ALL Data
The deliverable must include a **Node.js seed script** that:
1. Creates users in Firebase Auth (Email/Password)
2. Creates all Firestore documents for:
   - users
   - 3 classes (GI/GE/GC)
   - members subcollections
   - 6 subjects per class (exactly)
   - timetable for each class (weekly)
   - assessments (sample in current week)
   - optional initial messages in chats
3. Is **idempotent**:
   - If user email exists, reuse it
   - If docs exist, merge safely

### 11.2 Seed Data Requirements
- **3 Classes**
  - GI: Génie Informatique
  - GE: Génie Électrique
  - GC: Génie Civile

- **Subjects (6 per class)**  
Examples (can be used in seed):
GI:
1. Algorithmique
2. Programmation
3. Bases de données
4. Réseaux
5. Systèmes d’exploitation
6. Génie logiciel

GE:
1. Circuits électriques
2. Électronique analogique
3. Électronique numérique
4. Machines électriques
5. Automatique
6. Électrotechnique

GC:
1. Résistance des matériaux
2. Béton armé
3. Structures
4. Topographie
5. Hydraulique
6. Géotechnique

- **Teachers**
  - Exactly 6 teachers per class (one per subject)

- **Students**
  - Recommended 25 students per class (configurable)

- **Include “Amine Oukhouya” twice**
  - Student: `amine.oukouhya.student@EMG.ma`
  - Teacher: `amine.oukouhya.teacher@EMG.ma`

- **All other accounts**
  - Random realistic names
  - Emails must end with `@EMG.ma`

### 11.3 Email Naming Convention (Seed)
All emails: `...@EMG.ma`  
Recommended formats:
- Students: `prenom.nom.student.{classId}@EMG.ma`
- Teachers: `prenom.nom.teacher.{classId}@EMG.ma`

### 11.4 Seed Execution Deliverable
- Folder: `/seed/`
- Files:
  - `seed.js`
  - `package.json`
  - `README.md` with instructions
- Requires `serviceAccountKey.json` (downloaded from Firebase project settings)

---

## 12) Flutter Project Structure (Recommended)

### 12.1 Folder Structure (Clean Architecture light)
- `lib/`
  - `main.dart`
  - `app/` (router, theme, localization)
  - `features/`
    - `auth/`
    - `home/`
    - `schedule/`
    - `assessments/`
    - `attendance/`
    - `messages/`
    - `settings/`
  - `data/`
    - `firebase/` (services wrappers)
    - `repositories/`
  - `domain/`
    - `models/`
    - `usecases/`
  - `shared/`
    - `widgets/`
    - `utils/`

### 12.2 State Management
- Riverpod (recommended) or Bloc
- Firestore streams for real-time updates:
  - chat streams
  - attendance records

---

## 13) Required Flutter Packages
- Core:
  - `firebase_core`
  - `firebase_auth`
  - `cloud_firestore`
  - `cloud_functions`
  - `firebase_storage`
  - `firebase_messaging` (optional but recommended)
- UI:
  - `flutter_localizations`
- QR:
  - `qr_flutter` (teacher QR display)
  - `mobile_scanner` (student QR scan)

---

## 14) Notifications (FCM) — French
Recommended notifications:
- New assessment:
  - “Nouveau {type} en {module} — {date}”
- Assessment canceled:
  - “{type} annulé: {module}”
- Attendance opened (optional):
  - “Le QR de présence est ouvert (3 minutes).”

---

## 15) Non-Functional Requirements
- Performance: Home loads in <2 seconds typical network
- Data integrity: server timestamps for attendance
- Security: strict rules + functions for sensitive actions
- Reliability: functions idempotent, QR scan safe on retries
- Localization: French dates and UI labels

---

## 16) Testing Plan
### 16.1 Test Cases
- Login with seeded users (student + teacher)
- Student:
  - view schedule today/week
  - scan QR (success, expired, duplicate)
  - send messages (class + subject)
  - cannot create assessment
- Teacher:
  - select session then open QR
  - cannot open QR without session selection
  - view attendance list
  - create assessment (≤3/week) success
  - create assessment (>3/week) rejected
  - cancel assessment
- Settings:
  - change photo
  - change email (reauth scenario)
  - logout
  - immutable fields cannot change

---

## 17) Deployment & Environments
- Firebase projects:
  - `study-planner-dev` (development)
  - `study-planner-prod` (production)
- Deploy commands:
  - Firestore Rules: `firebase deploy --only firestore:rules`
  - Functions: `firebase deploy --only functions`
- Flutter:
  - Android: release build (AAB) → Play Console

---

## 18) Deliverables Checklist (What must be produced)
1. ✅ Flutter app with all screens & flows described
2. ✅ Firebase project configured (Auth, Firestore, Storage, Functions)
3. ✅ Firestore rules implemented (secure access)
4. ✅ Cloud Functions implemented:
   - createAttendanceSession
   - submitAttendance
   - assessment CRUD + constraints
5. ✅ Full seeding scripts:
   - creates Auth users + Firestore data
   - includes “Amine Oukhouya” in students and teachers
   - all emails end with `@EMG.ma`
6. ✅ Design system applied:
   - primary #10437A
   - secondary #E1A626
   - consistent professional + creative UI

---
**End of PRD**
