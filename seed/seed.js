/**
 * Study Planner - Seed Script
 *
 * Populates Firebase Auth and Firestore with demo data.
 * Idempotent: safe to run multiple times.
 */

import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync, writeFileSync, unlinkSync } from 'fs';
import { homedir, tmpdir } from 'os';
import { join } from 'path';

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_PASSWORD = 'StudyPlanner2026!';
const PROJECT_ID = 'studyplanner-dev-emg';

// Firebase CLI's public OAuth client credentials (embedded in firebase-tools source)
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';

let tempAdcPath = null;

// Try serviceAccountKey.json first, then fall back to Firebase CLI credentials
if (existsSync('./serviceAccountKey.json')) {
  console.log('🔑 Using serviceAccountKey.json');
  const serviceAccount = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
  initializeApp({ credential: cert(serviceAccount) });
} else {
  console.log('🔑 serviceAccountKey.json not found, using Firebase CLI credentials...');
  const configPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!existsSync(configPath)) {
    console.error('❌ Firebase CLI not logged in! Run: firebase login');
    process.exit(1);
  }
  const cliConfig = JSON.parse(readFileSync(configPath, 'utf8'));
  const refreshToken = cliConfig.tokens?.refresh_token;
  if (!refreshToken) {
    console.error('❌ No refresh token in Firebase CLI config. Run: firebase login --reauth');
    process.exit(1);
  }

  // Create a temporary ADC file in "authorized_user" format so Firestore gRPC works
  tempAdcPath = join(tmpdir(), `firebase-adc-${Date.now()}.json`);
  writeFileSync(tempAdcPath, JSON.stringify({
    type: 'authorized_user',
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
  }));
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tempAdcPath;

  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  console.log(`  ✓ Authenticated via Firebase CLI for project: ${PROJECT_ID}`);
}

// Clean up temp ADC file on exit
function cleanupTempAdc() {
  if (tempAdcPath && existsSync(tempAdcPath)) {
    try { unlinkSync(tempAdcPath); } catch {}
  }
}
process.on('exit', cleanupTempAdc);
process.on('SIGINT', () => { cleanupTempAdc(); process.exit(1); });

const auth = getAuth();
const db = getFirestore();

// ─────────────────────────────────────────────────────────────────────────────
// Data Definitions
// ─────────────────────────────────────────────────────────────────────────────

const CLASSES = [
  { id: 'GI', name: 'Génie Informatique' },
  { id: 'GE', name: 'Génie Électrique' },
  { id: 'GC', name: 'Génie Civil' },
];

const SUBJECTS = [
  { id: 'math', name: 'Mathématiques' },
  { id: 'phys', name: 'Physique' },
  { id: 'info', name: 'Informatique' },
  { id: 'angl', name: 'Anglais' },
  { id: 'comm', name: 'Communication' },
  { id: 'spec', name: 'Spécialité' }, // Will be customized per class
];

// Specialty names per class
const SPECIALTY_NAMES = {
  GI: 'Développement Logiciel',
  GE: 'Électronique de Puissance',
  GC: 'Structures et Béton',
};

// Teachers (shared across classes for some subjects)
const TEACHERS = [
  // Math teachers
  { firstName: 'Ahmed', lastName: 'Benali', subject: 'math' },
  { firstName: 'Fatima', lastName: 'Zahrani', subject: 'math' },
  // Physics teachers
  { firstName: 'Mohammed', lastName: 'Idrissi', subject: 'phys' },
  { firstName: 'Khadija', lastName: 'Amrani', subject: 'phys' },
  // Informatics teachers
  { firstName: 'Youssef', lastName: 'Tazi', subject: 'info' },
  { firstName: 'Samira', lastName: 'Bouazza', subject: 'info' },
  // English teachers
  { firstName: 'Rachid', lastName: 'Fassi', subject: 'angl' },
  // Communication teachers
  { firstName: 'Nadia', lastName: 'Chraibi', subject: 'comm' },
  // Specialty teachers (one per class)
  { firstName: 'Omar', lastName: 'Kettani', subject: 'spec', classOnly: 'GI' },
  { firstName: 'Hassan', lastName: 'Berrada', subject: 'spec', classOnly: 'GE' },
  { firstName: 'Laila', lastName: 'Filali', subject: 'spec', classOnly: 'GC' },
];

// Student names (will be distributed across classes)
const STUDENT_FIRST_NAMES = [
  'Adam', 'Ayman', 'Bilal', 'Chakib', 'Driss', 'Elias', 'Farid', 'Ghali',
  'Hamza', 'Ilyas', 'Jalil', 'Karim', 'Lotfi', 'Mehdi', 'Nabil', 'Omar',
  'Rachid', 'Samir', 'Tarik', 'Walid', 'Yassir', 'Zakaria', 'Anouar', 'Badr', 'Chadi',
  'Aicha', 'Basma', 'Chaimae', 'Dounia', 'Fadwa', 'Ghita', 'Hajar', 'Imane',
  'Jihane', 'Kenza', 'Lamia', 'Meryem', 'Nora', 'Oumaima', 'Rania', 'Salma',
  'Touria', 'Wiam', 'Yasmine', 'Zineb', 'Amina', 'Btissam', 'Chaima', 'Dina', 'Fatima',
];

const STUDENT_LAST_NAMES = [
  'Alaoui', 'Benjelloun', 'Cherkaoui', 'Daoudi', 'El Amrani', 'Fassi', 'Guessous',
  'Hamdaoui', 'Idrissi', 'Jebli', 'Kettani', 'Lahlou', 'Mansouri', 'Naciri',
  'Ouazzani', 'Qabbaj', 'Rahmani', 'Sbai', 'Tazi', 'Zniber', 'Bennis', 'Chraibi',
  'Doukkali', 'El Fassi', 'Filali', 'Ghazouani', 'Hajji', 'Ibrahimi', 'Jilali',
];

// Timetable template (same for all classes, different rooms)
const TIMETABLE_TEMPLATE = [
  // Monday
  { dayOfWeek: 1, startMinute: 8 * 60, endMinute: 10 * 60, subjectIndex: 0 }, // Math
  { dayOfWeek: 1, startMinute: 10 * 60 + 15, endMinute: 12 * 60 + 15, subjectIndex: 1 }, // Phys
  { dayOfWeek: 1, startMinute: 14 * 60, endMinute: 16 * 60, subjectIndex: 2 }, // Info
  // Tuesday
  { dayOfWeek: 2, startMinute: 8 * 60, endMinute: 10 * 60, subjectIndex: 3 }, // Angl
  { dayOfWeek: 2, startMinute: 10 * 60 + 15, endMinute: 12 * 60 + 15, subjectIndex: 4 }, // Comm
  { dayOfWeek: 2, startMinute: 14 * 60, endMinute: 16 * 60, subjectIndex: 5 }, // Spec
  // Wednesday
  { dayOfWeek: 3, startMinute: 8 * 60, endMinute: 10 * 60, subjectIndex: 0 }, // Math
  { dayOfWeek: 3, startMinute: 10 * 60 + 15, endMinute: 12 * 60 + 15, subjectIndex: 2 }, // Info
  { dayOfWeek: 3, startMinute: 14 * 60, endMinute: 16 * 60, subjectIndex: 1 }, // Phys
  // Thursday
  { dayOfWeek: 4, startMinute: 8 * 60, endMinute: 10 * 60, subjectIndex: 5 }, // Spec
  { dayOfWeek: 4, startMinute: 10 * 60 + 15, endMinute: 12 * 60 + 15, subjectIndex: 0 }, // Math
  { dayOfWeek: 4, startMinute: 14 * 60, endMinute: 16 * 60, subjectIndex: 3 }, // Angl
  // Friday
  { dayOfWeek: 5, startMinute: 8 * 60, endMinute: 10 * 60, subjectIndex: 4 }, // Comm
  { dayOfWeek: 5, startMinute: 10 * 60 + 15, endMinute: 12 * 60 + 15, subjectIndex: 2 }, // Info
  { dayOfWeek: 5, startMinute: 14 * 60, endMinute: 16 * 60, subjectIndex: 5 }, // Spec
];

const ROOMS = {
  GI: ['A101', 'A102', 'Lab Info 1'],
  GE: ['B201', 'B202', 'Lab Elec 1'],
  GC: ['C301', 'C302', 'Lab Meca 1'],
};

// ─────────────────────────────────────────────────────────────────────────────
// Helper Functions
// ─────────────────────────────────────────────────────────────────────────────

function generateEmail(firstName, lastName) {
  const clean = (s) => s.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '') // Remove accents
    .replace(/\s+/g, '.');
  return `${clean(firstName)}.${clean(lastName)}@EMG.ma`;
}

function generatePersonalNumber(prefix, index) {
  return `${prefix}${String(index).padStart(4, '0')}`;
}

async function getOrCreateUser(email, displayName, password = DEFAULT_PASSWORD) {
  try {
    // Try to get existing user
    const user = await auth.getUserByEmail(email);
    console.log(`  ✓ User exists: ${email}`);
    return user.uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      // Create new user
      const user = await auth.createUser({
        email,
        password,
        displayName,
        emailVerified: true,
      });
      console.log(`  + Created user: ${email}`);
      return user.uid;
    }
    throw error;
  }
}

function getISOWeekDates() {
  const now = new Date();
  const dayOfWeek = now.getDay() || 7; // Sunday = 7
  const monday = new Date(now);
  monday.setDate(now.getDate() - dayOfWeek + 1);
  monday.setHours(0, 0, 0, 0);

  const dates = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(monday);
    d.setDate(monday.getDate() + i);
    dates.push(d);
  }
  return dates;
}

// ─────────────────────────────────────────────────────────────────────────────
// Seed Functions
// ─────────────────────────────────────────────────────────────────────────────

async function seedTeachers() {
  console.log('\n📚 Seeding teachers...');
  const teacherMap = {}; // subject -> [{ uid, classIds }]

  for (const teacher of TEACHERS) {
    const fullName = `${teacher.firstName} ${teacher.lastName}`;
    const email = generateEmail(teacher.firstName, teacher.lastName);
    const uid = await getOrCreateUser(email, fullName);

    // Determine which classes this teacher teaches
    let classIds;
    if (teacher.classOnly) {
      classIds = [teacher.classOnly];
    } else {
      // Distribute teachers across classes
      // First teacher of each subject: GI, GE
      // Second teacher (if exists): GC
      if (!teacherMap[teacher.subject]) {
        teacherMap[teacher.subject] = [];
      }
      const teacherIndex = teacherMap[teacher.subject].length;
      if (teacherIndex === 0) {
        classIds = ['GI', 'GE'];
      } else {
        classIds = ['GC'];
      }
    }

    // Store for later reference
    if (!teacherMap[teacher.subject]) {
      teacherMap[teacher.subject] = [];
    }
    teacherMap[teacher.subject].push({ uid, classIds, fullName, email });

    // Create/update Firestore user document
    const personalNumber = generatePersonalNumber('T', TEACHERS.indexOf(teacher) + 1);
    await db.collection('users').doc(uid).set({
      role: 'teacher',
      fullName,
      personalNumber,
      email,
      teacherClassIds: classIds,
      photoURL: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  return teacherMap;
}

async function seedStudents() {
  console.log('\n🎓 Seeding students...');
  const studentMap = {}; // classId -> [{ uid, fullName }]

  let studentIndex = 0;
  const studentsPerClass = 25;

  for (const cls of CLASSES) {
    studentMap[cls.id] = [];

    for (let i = 0; i < studentsPerClass; i++) {
      // Special case: Amine Oukhouya in GI
      let firstName, lastName;
      if (cls.id === 'GI' && i === 0) {
        firstName = 'Amine';
        lastName = 'Oukhouya';
      } else {
        firstName = STUDENT_FIRST_NAMES[studentIndex % STUDENT_FIRST_NAMES.length];
        lastName = STUDENT_LAST_NAMES[studentIndex % STUDENT_LAST_NAMES.length];
      }

      const fullName = `${firstName} ${lastName}`;
      const email = generateEmail(firstName, lastName);
      const uid = await getOrCreateUser(email, fullName);

      const personalNumber = generatePersonalNumber('S', studentIndex + 1);

      // Create/update Firestore user document
      await db.collection('users').doc(uid).set({
        role: 'student',
        fullName,
        personalNumber,
        email,
        classId: cls.id,
        photoURL: null,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      studentMap[cls.id].push({ uid, fullName });
      studentIndex++;
    }
  }

  return studentMap;
}

async function seedClasses(teacherMap, studentMap) {
  console.log('\n🏫 Seeding classes...');

  for (const cls of CLASSES) {
    // Create class document
    await db.collection('classes').doc(cls.id).set({
      name: cls.name,
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`  ✓ Class: ${cls.name}`);

    // Seed subjects
    console.log(`    📖 Subjects for ${cls.id}:`);
    for (let i = 0; i < SUBJECTS.length; i++) {
      const subject = SUBJECTS[i];
      const subjectName = subject.id === 'spec'
        ? SPECIALTY_NAMES[cls.id]
        : subject.name;

      // Find teacher for this subject and class
      const teachers = teacherMap[subject.id] || [];
      const teacher = teachers.find(t => t.classIds.includes(cls.id));

      await db.collection('classes').doc(cls.id)
        .collection('subjects').doc(subject.id).set({
          name: subjectName,
          teacherUid: teacher?.uid || null,
          teacherName: teacher?.fullName || null,
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      console.log(`      - ${subjectName} (${teacher?.fullName || 'No teacher'})`);
    }

    // Seed members (students)
    console.log(`    👥 Members for ${cls.id}:`);
    const students = studentMap[cls.id] || [];
    for (const student of students) {
      await db.collection('classes').doc(cls.id)
        .collection('members').doc(student.uid).set({
          role: 'student',
          joinedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    console.log(`      - ${students.length} students`);

    // Add teachers as members
    const classTeachers = new Set();
    for (const subject of SUBJECTS) {
      const teachers = teacherMap[subject.id] || [];
      const teacher = teachers.find(t => t.classIds.includes(cls.id));
      if (teacher) classTeachers.add(teacher.uid);
    }
    for (const teacherUid of classTeachers) {
      await db.collection('classes').doc(cls.id)
        .collection('members').doc(teacherUid).set({
          role: 'teacher',
          joinedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    console.log(`      - ${classTeachers.size} teachers`);

    // Seed timetable
    console.log(`    📅 Timetable for ${cls.id}:`);
    let slotCount = 0;
    for (const slot of TIMETABLE_TEMPLATE) {
      const subject = SUBJECTS[slot.subjectIndex];
      const teachers = teacherMap[subject.id] || [];
      const teacher = teachers.find(t => t.classIds.includes(cls.id));

      const slotId = `${cls.id}_${slot.dayOfWeek}_${slot.startMinute}`;
      const roomIndex = slot.subjectIndex % ROOMS[cls.id].length;

      await db.collection('classes').doc(cls.id)
        .collection('timetableSlots').doc(slotId).set({
          dayOfWeek: slot.dayOfWeek,
          startMinute: slot.startMinute,
          endMinute: slot.endMinute,
          subjectId: subject.id,
          subjectName: subject.id === 'spec' ? SPECIALTY_NAMES[cls.id] : subject.name,
          teacherUid: teacher?.uid || null,
          teacherName: teacher?.fullName || null,
          room: ROOMS[cls.id][roomIndex],
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      slotCount++;
    }
    console.log(`      - ${slotCount} slots`);
  }
}

async function seedAssessments(teacherMap) {
  console.log('\n📝 Seeding assessments...');

  const weekDates = getISOWeekDates();
  const assessmentTypes = ['exam', 'quiz', 'project'];

  for (const cls of CLASSES) {
    console.log(`  ${cls.id}:`);

    // Create 2 assessments per class for current week
    for (let i = 0; i < 2; i++) {
      const subject = SUBJECTS[i % SUBJECTS.length];
      const teachers = teacherMap[subject.id] || [];
      const teacher = teachers.find(t => t.classIds.includes(cls.id));

      // Schedule on different days
      const dayIndex = i + 2; // Wed and Thu
      const assessmentDate = new Date(weekDates[dayIndex]);
      assessmentDate.setHours(10, 0, 0, 0);

      const assessmentId = `${cls.id}_${subject.id}_${assessmentDate.toISOString().split('T')[0]}`;

      await db.collection('classes').doc(cls.id)
        .collection('assessments').doc(assessmentId).set({
          subjectId: subject.id,
          subjectName: subject.id === 'spec' ? SPECIALTY_NAMES[cls.id] : subject.name,
          title: `${assessmentTypes[i % assessmentTypes.length].charAt(0).toUpperCase() + assessmentTypes[i % assessmentTypes.length].slice(1)} - ${subject.name}`,
          type: assessmentTypes[i % assessmentTypes.length],
          dateTime: assessmentDate,
          status: 'scheduled',
          teacherUid: teacher?.uid || null,
          teacherName: teacher?.fullName || null,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

      console.log(`    + ${assessmentTypes[i % assessmentTypes.length]}: ${subject.name} on ${assessmentDate.toLocaleDateString('fr-FR')}`);
    }
  }
}

async function printVerification() {
  console.log('\n📊 Verification:');

  // Count users
  const usersSnap = await db.collection('users').get();
  const students = usersSnap.docs.filter(d => d.data().role === 'student');
  const teachers = usersSnap.docs.filter(d => d.data().role === 'teacher');
  console.log(`  Users: ${usersSnap.size} total (${students.length} students, ${teachers.length} teachers)`);

  // Count per class
  for (const cls of CLASSES) {
    const classDoc = await db.collection('classes').doc(cls.id).get();
    const subjectsSnap = await db.collection('classes').doc(cls.id).collection('subjects').get();
    const membersSnap = await db.collection('classes').doc(cls.id).collection('members').get();
    const slotsSnap = await db.collection('classes').doc(cls.id).collection('timetableSlots').get();
    const assessmentsSnap = await db.collection('classes').doc(cls.id).collection('assessments').get();

    const studentMembers = membersSnap.docs.filter(d => d.data().role === 'student');
    const teacherMembers = membersSnap.docs.filter(d => d.data().role === 'teacher');

    console.log(`  ${cls.id} (${classDoc.data()?.name}):`);
    console.log(`    - Subjects: ${subjectsSnap.size}`);
    console.log(`    - Students: ${studentMembers.length}`);
    console.log(`    - Teachers: ${teacherMembers.length}`);
    console.log(`    - Timetable slots: ${slotsSnap.size}`);
    console.log(`    - Assessments: ${assessmentsSnap.size}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🚀 Study Planner - Seed Script');
  console.log('================================\n');

  try {
    const teacherMap = await seedTeachers();
    const studentMap = await seedStudents();
    await seedClasses(teacherMap, studentMap);
    await seedAssessments(teacherMap);
    await printVerification();

    console.log('\n✅ Seeding complete!');
    console.log(`\n💡 Default password for all accounts: ${DEFAULT_PASSWORD}`);
    console.log('   Special account: amine.oukhouya@EMG.ma (student in GI)');
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

main();
