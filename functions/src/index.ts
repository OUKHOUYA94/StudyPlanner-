import * as admin from "firebase-admin";

admin.initializeApp();

export {createAttendanceSession, submitAttendance} from "./attendance";
export {createAssessment, updateAssessment, cancelAssessment} from "./assessments";
export {onAssessmentCreated, onAssessmentUpdated} from "./notifications";
