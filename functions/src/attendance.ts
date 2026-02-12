import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import * as crypto from "crypto";

const db = admin.firestore();

/**
 * createAttendanceSession
 *
 * Called by a teacher to open attendance QR for a specific timetable slot.
 * Creates a session with a 3-minute expiration and returns a plaintext token.
 *
 * Input: { classId: string, timetableSlotId: string }
 * Output: { sessionId: string, token: string, expiresAt: string }
 */
export const createAttendanceSession = onCall(async (request) => {
  // 1. Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  const uid = request.auth.uid;

  // 2. Validate input
  const {classId, timetableSlotId} = request.data;
  if (!classId || typeof classId !== "string") {
    throw new HttpsError("invalid-argument", "classId est requis.");
  }
  if (!timetableSlotId || typeof timetableSlotId !== "string") {
    throw new HttpsError("invalid-argument", "timetableSlotId est requis.");
  }

  // 3. Verify caller is a teacher
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Utilisateur introuvable.");
  }
  const userData = userDoc.data()!;
  if (userData.role !== "teacher") {
    throw new HttpsError(
      "permission-denied",
      "Seuls les enseignants peuvent ouvrir une session."
    );
  }

  // 4. Verify teacher has access to the class
  const teacherClassIds: string[] = userData.teacherClassIds || [];
  if (!teacherClassIds.includes(classId)) {
    throw new HttpsError(
      "permission-denied",
      "Vous n'avez pas acc\u00e8s \u00e0 cette classe."
    );
  }

  // 5. Verify timetable slot exists and belongs to the class
  const slotDoc = await db
    .collection("classes")
    .doc(classId)
    .collection("timetableSlots")
    .doc(timetableSlotId)
    .get();

  if (!slotDoc.exists) {
    throw new HttpsError("not-found", "S\u00e9ance introuvable.");
  }

  const slotData = slotDoc.data()!;

  // 6. Verify the slot is for today (dayOfWeek: 1=Mon..7=Sun)
  const now = new Date();
  const todayDow = now.getDay() === 0 ? 7 : now.getDay(); // JS: 0=Sun -> 7
  if (slotData.dayOfWeek !== todayDow) {
    throw new HttpsError(
      "failed-precondition",
      "Cette s\u00e9ance n'est pas programm\u00e9e aujourd'hui."
    );
  }

  // 7. Generate token and hash
  const token = crypto.randomBytes(32).toString("hex");
  const tokenHash = crypto.createHash("sha256").update(token).digest("hex");

  // 8. Calculate expiration (3 minutes)
  const startAt = admin.firestore.Timestamp.now();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    startAt.toMillis() + 3 * 60 * 1000
  );

  // 9. Create attendance session document
  const sessionRef = await db
    .collection("classes")
    .doc(classId)
    .collection("attendanceSessions")
    .add({
      teacherUid: uid,
      timetableSlotId: timetableSlotId,
      startAt: startAt,
      expiresAt: expiresAt,
      status: "open",
      tokenHash: tokenHash,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return {
    sessionId: sessionRef.id,
    token: token,
    expiresAt: expiresAt.toDate().toISOString(),
  };
});

/**
 * submitAttendance
 *
 * Called by a student to record attendance by scanning a QR code.
 * Validates the token, checks expiration, prevents duplicates,
 * and writes the attendance record with a server timestamp.
 *
 * Input: { classId, sessionId, token, clientScannedAt? }
 * Output: { success: true, checkedAt: string }
 */
export const submitAttendance = onCall(async (request) => {
  // 1. Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  const uid = request.auth.uid;

  // 2. Validate input
  const {classId, sessionId, token, clientScannedAt} = request.data;
  if (!classId || typeof classId !== "string") {
    throw new HttpsError("invalid-argument", "classId est requis.");
  }
  if (!sessionId || typeof sessionId !== "string") {
    throw new HttpsError("invalid-argument", "sessionId est requis.");
  }
  if (!token || typeof token !== "string") {
    throw new HttpsError("invalid-argument", "token est requis.");
  }

  // 3. Verify caller is a student
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Utilisateur introuvable.");
  }
  const userData = userDoc.data()!;
  if (userData.role !== "student") {
    throw new HttpsError(
      "permission-denied",
      "Seuls les \u00e9tudiants peuvent scanner."
    );
  }

  // 4. Verify student belongs to the class
  if (userData.classId !== classId) {
    throw new HttpsError(
      "permission-denied",
      "Vous n'appartenez pas \u00e0 cette classe."
    );
  }

  // 5. Fetch the attendance session
  const sessionDoc = await db
    .collection("classes")
    .doc(classId)
    .collection("attendanceSessions")
    .doc(sessionId)
    .get();

  if (!sessionDoc.exists) {
    throw new HttpsError("not-found", "Session de pr\u00e9sence introuvable.");
  }
  const sessionData = sessionDoc.data()!;

  // 6. Verify session is open
  if (sessionData.status !== "open") {
    throw new HttpsError(
      "failed-precondition",
      "La session de pr\u00e9sence est ferm\u00e9e."
    );
  }

  // 7. Verify session has not expired
  const now = admin.firestore.Timestamp.now();
  const expiresAt = sessionData.expiresAt as admin.firestore.Timestamp;
  if (now.toMillis() > expiresAt.toMillis()) {
    throw new HttpsError(
      "deadline-exceeded",
      "La session de pr\u00e9sence a expir\u00e9."
    );
  }

  // 8. Verify token hash matches
  const submittedHash = crypto
    .createHash("sha256")
    .update(token)
    .digest("hex");
  if (submittedHash !== sessionData.tokenHash) {
    throw new HttpsError(
      "permission-denied",
      "Token de pr\u00e9sence invalide."
    );
  }

  // 9. Check for duplicate scan
  const recordRef = db
    .collection("classes")
    .doc(classId)
    .collection("attendanceSessions")
    .doc(sessionId)
    .collection("records")
    .doc(uid);

  const existingRecord = await recordRef.get();
  if (existingRecord.exists) {
    throw new HttpsError(
      "already-exists",
      "Pr\u00e9sence d\u00e9j\u00e0 enregistr\u00e9e."
    );
  }

  // 10. Write the attendance record with server timestamp
  const checkedAt = admin.firestore.FieldValue.serverTimestamp();
  await recordRef.set({
    present: true,
    checkedAt: checkedAt,
    clientScannedAt: clientScannedAt || null,
    method: "qr",
  });

  return {
    success: true,
    checkedAt: new Date().toISOString(),
  };
});
