# API Documentation (Firebase)

## Overview
Study Planner uses Firebase (Auth, Firestore, Cloud Functions, Storage, FCM).
This document defines callable functions and Firestore data contracts.

---

## Auth
- Provider: Firebase Auth (Email/Password)
- Role source: `users/{uid}.role` (student|teacher)

---

## Cloud Functions (Callable or HTTPS)

### Attendance
- createAttendanceSession(classId, timetableSlotId)
  - Role: teacher
  - Returns: sessionId, token, expiresAt
- submitAttendance(classId, sessionId, token, clientScannedAt?)
  - Role: student
  - Writes: attendance record with `checkedAt = serverTimestamp()`

### Assessments
- createAssessment(classId, payload)
  - Role: teacher
  - Rule: max 3 assessments per ISO week per class
- updateAssessment(classId, assessmentId, payload)
  - Role: teacher
  - Rule: max 3 assessments per ISO week per class
- cancelAssessment(classId, assessmentId, reason?)
  - Role: teacher

### Notifications (Firestore Triggers)
- onAssessmentCreated
  - Trigger: classes/{classId}/assessments/{assessmentId} created
  - Action: Sends FCM notification to all class members
  - Title: "Nouvel examen"
  - Body: "{subjectName}: {title}"
- onAssessmentUpdated
  - Trigger: classes/{classId}/assessments/{assessmentId} updated
  - Action: Sends FCM notification if status changed to canceled OR dateTime changed
  - Title: "Examen annulé" or "Examen modifié"
  - Body: "{subjectName}: {title}" or "{subjectName}: {title} - {new date}"

---

## Firestore Collections
- users/{uid}
- users/{uid}/devices/{token} (FCM device tokens)
- classes/{classId}
- classes/{classId}/members/{uid}
- classes/{classId}/subjects/{subjectId}
- classes/{classId}/timetableSlots/{slotId}
- classes/{classId}/assessments/{assessmentId}
- classes/{classId}/attendanceSessions/{sessionId}
- classes/{classId}/attendanceSessions/{sessionId}/records/{studentUid}
- classes/{classId}/classChat/messages/{messageId}
- classes/{classId}/subjectChats/{subjectId}/messages/{messageId}

---

## Security Rules (Detailed -- firestore.rules)

### Helper functions
- `isAuth()` -- caller is authenticated
- `isStudent()` / `isTeacher()` -- role check via users/{uid}.role
- `studentInClass(classId)` -- student's classId matches
- `teacherInClass(classId)` -- classId in teacher's teacherClassIds
- `memberOfClass(classId)` -- student OR teacher in class
- `teachesSubject(classId, subjectId)` -- teacher's uid matches subject.teacherUid

### Per-collection rules

| Collection | Read | Write |
|---|---|---|
| `users/{userId}` | Own doc only | Update own doc; immutable fields enforced (role, fullName, personalNumber, classId, createdAt) |
| `users/{userId}/devices/{deviceId}` | Own devices only | Own devices (FCM tokens) |
| `classes/{classId}` | Class members | Denied (seed only) |
| `classes/{cid}/members/{uid}` | Class members | Denied |
| `classes/{cid}/subjects/{sid}` | Class members | Denied |
| `classes/{cid}/timetableSlots/{id}` | Class members | Denied |
| `classes/{cid}/assessments/{id}` | Class members | Denied (Cloud Functions only) |
| `classes/{cid}/attendanceSessions/{id}` | Class members | Denied (Cloud Functions only) |
| `classes/{cid}/attendanceSessions/{id}/records/{uid}` | Class members | Denied (Cloud Functions only) |
| `classes/{cid}/classChat/messages/{id}` | Class members | Create: class member, senderUid==caller, required fields, serverTimestamp |
| `classes/{cid}/subjectChats/{sid}/messages/{id}` | Student in class OR subject teacher | Create: same as class chat with subject access check |

### Chat message create constraints
- Required fields: senderUid, senderName, senderRole, text, createdAt
- createdAt must equal request.time (server timestamp)
- senderUid must equal caller uid
- No update or delete (v1)

### Storage rules (storage.rules)
- Profile photos: `/users/{userId}/profile.{ext}`
  - Read: any authenticated user
  - Write: own photo only, max 5 MB, image/* content type
- All other paths: denied

### Composite indexes (firestore.indexes.json)
- assessments: status + dateTime (ASC)
- assessments: subjectId + dateTime (ASC)
- messages: createdAt (DESC)
- timetableSlots: dayOfWeek + startMinute (ASC)

---

## Notes
Update this file whenever functions, params, or data contracts change.
