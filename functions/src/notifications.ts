/**
 * FCM Notification Cloud Functions
 *
 * Sends push notifications for assessment events.
 */

import * as admin from "firebase-admin";
import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Fetches all FCM tokens for members of a class.
 */
async function getClassMemberTokens(classId: string): Promise<string[]> {
  const membersSnap = await db
    .collection("classes")
    .doc(classId)
    .collection("members")
    .get();

  const tokens: string[] = [];

  for (const memberDoc of membersSnap.docs) {
    const uid = memberDoc.id;
    const devicesSnap = await db
      .collection("users")
      .doc(uid)
      .collection("devices")
      .get();

    for (const deviceDoc of devicesSnap.docs) {
      const token = deviceDoc.data().token;
      if (token) {
        tokens.push(token);
      }
    }
  }

  return tokens;
}

/**
 * Sends FCM notification to multiple tokens.
 * Handles invalid tokens by removing them from Firestore.
 */
async function sendNotification(
  tokens: string[],
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;

  // FCM multicast limit is 500 tokens
  const chunks: string[][] = [];
  for (let i = 0; i < tokens.length; i += 500) {
    chunks.push(tokens.slice(i, i + 500));
  }

  for (const chunk of chunks) {
    try {
      const response = await messaging.sendEachForMulticast({
        tokens: chunk,
        notification: {
          title,
          body,
        },
        data: data || {},
        android: {
          priority: "high",
          notification: {
            channelId: "assessments",
            priority: "high",
          },
        },
      });

      // Clean up invalid tokens
      if (response.failureCount > 0) {
        const invalidTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            const errorCode = resp.error?.code;
            if (
              errorCode === "messaging/invalid-registration-token" ||
              errorCode === "messaging/registration-token-not-registered"
            ) {
              invalidTokens.push(chunk[idx]);
            }
          }
        });

        // Remove invalid tokens from Firestore
        for (const invalidToken of invalidTokens) {
          // Find and delete the token document
          const tokenQuery = await db
            .collectionGroup("devices")
            .where("token", "==", invalidToken)
            .get();

          for (const doc of tokenQuery.docs) {
            await doc.ref.delete();
          }
        }
      }
    } catch (error) {
      console.error("FCM send error:", error);
    }
  }
}

/**
 * Trigger: Assessment created
 * Notifies all class members about new assessment.
 */
export const onAssessmentCreated = onDocumentCreated(
  "classes/{classId}/assessments/{assessmentId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const classId = event.params.classId;
    const data = snapshot.data();

    const title = "Nouvel examen";
    const body = `${data.subjectName}: ${data.title}`;

    const tokens = await getClassMemberTokens(classId);
    await sendNotification(tokens, title, body, {
      type: "assessment_created",
      classId,
      assessmentId: event.params.assessmentId,
    });

    console.log(`Notification sent for new assessment in ${classId}`);
  }
);

/**
 * Trigger: Assessment updated
 * Notifies class members if assessment is canceled or rescheduled.
 */
export const onAssessmentUpdated = onDocumentUpdated(
  "classes/{classId}/assessments/{assessmentId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const classId = event.params.classId;

    // Check if status changed to canceled
    if (before.status !== "canceled" && after.status === "canceled") {
      const title = "Examen annulé";
      const body = `${after.subjectName}: ${after.title}`;

      const tokens = await getClassMemberTokens(classId);
      await sendNotification(tokens, title, body, {
        type: "assessment_canceled",
        classId,
        assessmentId: event.params.assessmentId,
      });

      console.log(`Notification sent for canceled assessment in ${classId}`);
      return;
    }

    // Check if date/time changed
    const beforeDate = before.dateTime?.toDate?.()?.getTime();
    const afterDate = after.dateTime?.toDate?.()?.getTime();

    if (beforeDate && afterDate && beforeDate !== afterDate) {
      const title = "Examen modifié";
      const newDate = after.dateTime.toDate();
      const dateStr = newDate.toLocaleDateString("fr-FR", {
        weekday: "long",
        day: "numeric",
        month: "long",
      });
      const body = `${after.subjectName}: ${after.title} - ${dateStr}`;

      const tokens = await getClassMemberTokens(classId);
      await sendNotification(tokens, title, body, {
        type: "assessment_updated",
        classId,
        assessmentId: event.params.assessmentId,
      });

      console.log(`Notification sent for rescheduled assessment in ${classId}`);
    }
  }
);
