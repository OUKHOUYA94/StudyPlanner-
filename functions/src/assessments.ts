import * as admin from "firebase-admin";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const db = admin.firestore();

/**
 * Returns the Monday 00:00 and next Monday 00:00 for the ISO week
 * containing the given date.
 */
function isoWeekBounds(date: Date): { weekStart: Date; weekEnd: Date } {
  const d = new Date(date);
  const day = d.getDay(); // 0=Sun, 1=Mon..6=Sat
  const diffToMonday = day === 0 ? -6 : 1 - day;
  const monday = new Date(d);
  monday.setDate(d.getDate() + diffToMonday);
  monday.setHours(0, 0, 0, 0);
  const nextMonday = new Date(monday);
  nextMonday.setDate(monday.getDate() + 7);
  return {weekStart: monday, weekEnd: nextMonday};
}

/**
 * Verify the caller is a teacher with access to the given class.
 * Returns the user document data.
 */
async function verifyTeacherAccess(
  uid: string,
  classId: string
): Promise<FirebaseFirestore.DocumentData> {
  const userDoc = await db.collection("users").doc(uid).get();
  if (!userDoc.exists) {
    throw new HttpsError("not-found", "Utilisateur introuvable.");
  }
  const userData = userDoc.data()!;
  if (userData.role !== "teacher") {
    throw new HttpsError(
      "permission-denied",
      "Seuls les enseignants peuvent gérer les examens."
    );
  }
  const teacherClassIds: string[] = userData.teacherClassIds || [];
  if (!teacherClassIds.includes(classId)) {
    throw new HttpsError(
      "permission-denied",
      "Vous n'avez pas accès à cette classe."
    );
  }
  return userData;
}

/**
 * createAssessment
 *
 * Called by a teacher to create an assessment for a class.
 * Enforces max 3 assessments per ISO week per class.
 *
 * Input: { classId, subjectId, title, type, dateTime (ISO string) }
 * Output: { assessmentId: string }
 */
export const createAssessment = onCall(async (request) => {
  // 1. Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  const uid = request.auth.uid;

  // 2. Validate input
  const {classId, subjectId, title, type, dateTime} = request.data;
  if (!classId || typeof classId !== "string") {
    throw new HttpsError("invalid-argument", "classId est requis.");
  }
  if (!subjectId || typeof subjectId !== "string") {
    throw new HttpsError("invalid-argument", "subjectId est requis.");
  }
  if (!title || typeof title !== "string") {
    throw new HttpsError("invalid-argument", "title est requis.");
  }
  if (!type || typeof type !== "string") {
    throw new HttpsError("invalid-argument", "type est requis.");
  }
  const validTypes = ["exam", "quiz", "homework", "project", "oral"];
  if (!validTypes.includes(type)) {
    throw new HttpsError(
      "invalid-argument",
      `Type invalide. Types autorisés : ${validTypes.join(", ")}.`
    );
  }
  if (!dateTime || typeof dateTime !== "string") {
    throw new HttpsError("invalid-argument", "dateTime est requis.");
  }
  const parsedDate = new Date(dateTime);
  if (isNaN(parsedDate.getTime())) {
    throw new HttpsError("invalid-argument", "dateTime invalide.");
  }

  // 3. Verify teacher + class access
  await verifyTeacherAccess(uid, classId);

  // 4. Enforce max 3 assessments per ISO week per class
  const {weekStart, weekEnd} = isoWeekBounds(parsedDate);
  const weekSnap = await db
    .collection("classes")
    .doc(classId)
    .collection("assessments")
    .where("dateTime", ">=", admin.firestore.Timestamp.fromDate(weekStart))
    .where("dateTime", "<", admin.firestore.Timestamp.fromDate(weekEnd))
    .where("status", "in", ["scheduled", "completed"])
    .get();

  if (weekSnap.size >= 3) {
    throw new HttpsError(
      "resource-exhausted",
      "Maximum 3 examens par semaine par classe atteint."
    );
  }

  // 5. Create assessment document
  const assessmentRef = await db
    .collection("classes")
    .doc(classId)
    .collection("assessments")
    .add({
      subjectId,
      title,
      type,
      dateTime: admin.firestore.Timestamp.fromDate(parsedDate),
      status: "scheduled",
      createdBy: uid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return {assessmentId: assessmentRef.id};
});

/**
 * updateAssessment
 *
 * Called by a teacher to update an existing assessment.
 * Only allows updating: title, type, subjectId, dateTime.
 * Re-checks the ISO week limit if dateTime changes.
 *
 * Input: { classId, assessmentId, title?, type?, subjectId?, dateTime? }
 * Output: { success: true }
 */
export const updateAssessment = onCall(async (request) => {
  // 1. Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  const uid = request.auth.uid;

  // 2. Validate input
  const {classId, assessmentId, ...fields} = request.data;
  if (!classId || typeof classId !== "string") {
    throw new HttpsError("invalid-argument", "classId est requis.");
  }
  if (!assessmentId || typeof assessmentId !== "string") {
    throw new HttpsError("invalid-argument", "assessmentId est requis.");
  }

  // 3. Verify teacher + class access
  await verifyTeacherAccess(uid, classId);

  // 4. Fetch existing assessment
  const assessmentRef = db
    .collection("classes")
    .doc(classId)
    .collection("assessments")
    .doc(assessmentId);
  const assessmentDoc = await assessmentRef.get();
  if (!assessmentDoc.exists) {
    throw new HttpsError("not-found", "Examen introuvable.");
  }
  const existing = assessmentDoc.data()!;

  if (existing.status === "canceled") {
    throw new HttpsError(
      "failed-precondition",
      "Impossible de modifier un examen annulé."
    );
  }

  // 5. Build update object with only allowed fields
  const update: Record<string, unknown> = {};
  const allowedFields = ["title", "type", "subjectId", "dateTime"];

  for (const key of allowedFields) {
    if (fields[key] !== undefined) {
      if (key === "type") {
        const validTypes = ["exam", "quiz", "homework", "project", "oral"];
        if (!validTypes.includes(fields[key])) {
          throw new HttpsError(
            "invalid-argument",
            `Type invalide. Types autorisés : ${validTypes.join(", ")}.`
          );
        }
        update[key] = fields[key];
      } else if (key === "dateTime") {
        const newDate = new Date(fields[key]);
        if (isNaN(newDate.getTime())) {
          throw new HttpsError("invalid-argument", "dateTime invalide.");
        }
        update[key] = admin.firestore.Timestamp.fromDate(newDate);
      } else {
        update[key] = fields[key];
      }
    }
  }

  if (Object.keys(update).length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Aucun champ à mettre à jour."
    );
  }

  // 6. If dateTime changed, re-check weekly limit
  if (update.dateTime) {
    const newTs = update.dateTime as admin.firestore.Timestamp;
    const newDate = newTs.toDate();
    const {weekStart, weekEnd} = isoWeekBounds(newDate);

    const weekSnap = await db
      .collection("classes")
      .doc(classId)
      .collection("assessments")
      .where("dateTime", ">=", admin.firestore.Timestamp.fromDate(weekStart))
      .where("dateTime", "<", admin.firestore.Timestamp.fromDate(weekEnd))
      .where("status", "in", ["scheduled", "completed"])
      .get();

    // Exclude the current assessment from the count
    const otherCount = weekSnap.docs.filter(
      (d) => d.id !== assessmentId
    ).length;

    if (otherCount >= 3) {
      throw new HttpsError(
        "resource-exhausted",
        "Maximum 3 examens par semaine par classe atteint."
      );
    }
  }

  // 7. Apply update
  update.updatedAt = admin.firestore.FieldValue.serverTimestamp();
  update.updatedBy = uid;
  await assessmentRef.update(update);

  return {success: true};
});

/**
 * cancelAssessment
 *
 * Called by a teacher to cancel an assessment.
 * Sets status to "canceled" and optionally stores a reason.
 *
 * Input: { classId, assessmentId, reason? }
 * Output: { success: true }
 */
export const cancelAssessment = onCall(async (request) => {
  // 1. Auth check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  const uid = request.auth.uid;

  // 2. Validate input
  const {classId, assessmentId, reason} = request.data;
  if (!classId || typeof classId !== "string") {
    throw new HttpsError("invalid-argument", "classId est requis.");
  }
  if (!assessmentId || typeof assessmentId !== "string") {
    throw new HttpsError("invalid-argument", "assessmentId est requis.");
  }

  // 3. Verify teacher + class access
  await verifyTeacherAccess(uid, classId);

  // 4. Fetch assessment
  const assessmentRef = db
    .collection("classes")
    .doc(classId)
    .collection("assessments")
    .doc(assessmentId);
  const assessmentDoc = await assessmentRef.get();
  if (!assessmentDoc.exists) {
    throw new HttpsError("not-found", "Examen introuvable.");
  }
  const existing = assessmentDoc.data()!;

  if (existing.status === "canceled") {
    throw new HttpsError(
      "failed-precondition",
      "Cet examen est déjà annulé."
    );
  }

  // 5. Cancel
  await assessmentRef.update({
    status: "canceled",
    canceledBy: uid,
    cancelReason: reason || null,
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {success: true};
});
