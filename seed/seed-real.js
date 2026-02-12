/**
 * Study Planner - Real Data Seed Script
 *
 * Creates GINF2 class with real students, teachers, subjects, and timetable.
 * Based on the user's Excel (student list) and PDF (emploi du temps).
 * Idempotent: safe to run multiple times.
 */

import { initializeApp, cert, applicationDefault } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync, writeFileSync, unlinkSync } from 'fs';
import { homedir, tmpdir } from 'os';
import { join } from 'path';

// ─────────────────────────────────────────────────────────────────────────────
// Firebase Init (same as seed.js — supports serviceAccountKey or CLI fallback)
// ─────────────────────────────────────────────────────────────────────────────

const PROJECT_ID = 'studyplanner-dev-emg';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
let tempAdcPath = null;

if (existsSync('./serviceAccountKey.json')) {
  console.log('🔑 Using serviceAccountKey.json');
  const sa = JSON.parse(readFileSync('./serviceAccountKey.json', 'utf8'));
  initializeApp({ credential: cert(sa) });
} else {
  console.log('🔑 Using Firebase CLI credentials...');
  const configPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!existsSync(configPath)) { console.error('❌ Firebase CLI not logged in!'); process.exit(1); }
  const cliConfig = JSON.parse(readFileSync(configPath, 'utf8'));
  const refreshToken = cliConfig.tokens?.refresh_token;
  if (!refreshToken) { console.error('❌ No refresh token. Run: firebase login --reauth'); process.exit(1); }
  tempAdcPath = join(tmpdir(), `firebase-adc-${Date.now()}.json`);
  writeFileSync(tempAdcPath, JSON.stringify({
    type: 'authorized_user',
    client_id: CLI_CLIENT_ID,
    client_secret: CLI_CLIENT_SECRET,
    refresh_token: refreshToken,
  }));
  process.env.GOOGLE_APPLICATION_CREDENTIALS = tempAdcPath;
  initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });
  console.log(`  ✓ Authenticated for project: ${PROJECT_ID}`);
}

function cleanupTempAdc() {
  if (tempAdcPath && existsSync(tempAdcPath)) { try { unlinkSync(tempAdcPath); } catch {} }
}
process.on('exit', cleanupTempAdc);
process.on('SIGINT', () => { cleanupTempAdc(); process.exit(1); });

const auth = getAuth();
const db = getFirestore();

// ─────────────────────────────────────────────────────────────────────────────
// Real Data — from Excel (students) and PDF (timetable)
// ─────────────────────────────────────────────────────────────────────────────

const CLASS_ID = 'GINF2';
const CLASS_NAME = '2ème année Génie Informatique (GINF2 TA)';
const ROOM = 'Salle 6';

// Students: parsed from Excel screenshot (Nom & Prénom = LastName FirstName)
const STUDENTS = [
  { n: 1,  firstName: 'Oussama',       lastName: 'El Barki',        password: '1671' },
  { n: 2,  firstName: 'Mohamed',       lastName: 'Hmitou',          password: '8816' },
  { n: 3,  firstName: 'Meryeme',       lastName: 'Hamoumi',         password: '8768' },
  { n: 4,  firstName: 'Amine',         lastName: 'Benoujeddi',      password: '8912' },
  { n: 5,  firstName: 'Achraf',        lastName: 'Habbass',         password: '3633' },
  { n: 6,  firstName: 'Mohamed',       lastName: 'Hasnaoui',        password: '7414' },
  { n: 7,  firstName: 'Imane',         lastName: 'Chakir',          password: '9209' },
  { n: 8,  firstName: 'Dina',          lastName: 'Boukhnif',        password: '2420' },
  { n: 9,  firstName: 'Chihab Eddine', lastName: 'Tai',             password: '7615' },
  { n: 10, firstName: 'Douae',         lastName: 'Boudriba',        password: '6029' },
  { n: 11, firstName: 'Nora',          lastName: 'Essafi',          password: '3949' },
  { n: 12, firstName: 'Amine',         lastName: 'Oukhouya',        password: '6160' },
  { n: 13, firstName: 'Ikram',         lastName: 'Boussouifa',      password: '3661' },
  { n: 14, firstName: 'Imane',         lastName: 'Doudouh',         password: '3765' },
  { n: 15, firstName: 'Aya',           lastName: 'Lebdaoui',        password: '2397' },
  { n: 16, firstName: 'Imad',          lastName: 'Hajbane',         password: '4589' },
  { n: 17, firstName: 'Anas',          lastName: 'El-Bouchti',      password: '3314' },
  { n: 18, firstName: 'Abdelouahed',   lastName: 'Ait-Essaih',      password: '6011' },
  { n: 19, firstName: 'Ayoub',         lastName: 'Boumghader',      password: '8250' },
  { n: 20, firstName: 'Azzeddine',     lastName: 'El Goujdali',     password: '5680' },
  { n: 21, firstName: 'Yassine',       lastName: 'Boutaleb',        password: '7549' },
];

// Teachers: from PDF timetable (Mme. = female, M. = male)
const TEACHERS = [
  { id: 'bouraqqadi',  displayName: 'Mme. Bouraqqadi',  lastName: 'Bouraqqadi',  subject: 'anglais' },
  { id: 'essalhi',     displayName: 'M. Essalhi',       lastName: 'Essalhi',     subject: 'francais' },
  { id: 'elkhrouite',  displayName: 'Mme. Elkhrouite',  lastName: 'Elkhrouite',  subject: 'poo' },
  { id: 'bara',        displayName: 'M. Bara',          lastName: 'Bara',        subject: 'dam' },
  { id: 'khald',       displayName: 'M. Khald',         lastName: 'Khald',       subject: 'web' },
  { id: 'hmami',       displayName: 'Mme. Hmami',       lastName: 'Hmami',       subject: 'data_ia' },
  { id: 'aarab',       displayName: 'Mme. Aarab',       lastName: 'Aarab',       subject: 'genie_log' },
];

// Subjects: from PDF
const SUBJECTS = [
  { id: 'anglais',    name: 'Anglais',                                        teacherId: 'bouraqqadi' },
  { id: 'francais',   name: 'Français',                                       teacherId: 'essalhi' },
  { id: 'poo',        name: 'Programmation Orientée Avancée',                  teacherId: 'elkhrouite' },
  { id: 'dam',        name: 'Développement des Applications Mobiles',          teacherId: 'bara' },
  { id: 'crypto',     name: 'Élément de cryptographie et sécurité des applications', teacherId: null },
  { id: 'web',        name: 'Technologies avancées du Web',                    teacherId: 'khald' },
  { id: 'data_ia',    name: 'Data science et IA',                             teacherId: 'hmami' },
  { id: 'genie_log',  name: 'Génie logiciel et modélisation orientée objet',   teacherId: 'aarab' },
];

// Timetable: current week S17 (Feb 2-7, 2026) from PDF
// dayOfWeek: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat
const TIMETABLE = [
  { dayOfWeek: 1, startMinute: 18*60, endMinute: 21*60, subjectId: 'francais' },
  { dayOfWeek: 2, startMinute: 18*60, endMinute: 21*60, subjectId: 'poo' },
  { dayOfWeek: 3, startMinute: 18*60, endMinute: 21*60, subjectId: 'dam' },
  { dayOfWeek: 4, startMinute: 18*60, endMinute: 21*60, subjectId: 'crypto' },
  { dayOfWeek: 5, startMinute: 18*60, endMinute: 21*60, subjectId: 'web' },
  { dayOfWeek: 6, startMinute: 9*60,  endMinute: 12*60, subjectId: 'data_ia' },
  { dayOfWeek: 6, startMinute: 13*60, endMinute: 16*60, subjectId: 'genie_log' },
];

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function generateEmail(firstName, lastName) {
  const clean = (s) => s.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '.');
  return `${clean(firstName)}.${clean(lastName)}@EMG.ma`;
}

async function getOrCreateUser(email, displayName, password) {
  try {
    const user = await auth.getUserByEmail(email);
    // Update password if user already exists
    await auth.updateUser(user.uid, { password, displayName });
    console.log(`  ✓ Updated: ${email}`);
    return user.uid;
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      const user = await auth.createUser({
        email, password, displayName, emailVerified: true,
      });
      console.log(`  + Created: ${email}`);
      return user.uid;
    }
    throw error;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Seed Functions
// ─────────────────────────────────────────────────────────────────────────────

async function seedTeachers() {
  console.log('\n👩‍🏫 Seeding teachers...');
  const teacherMap = {}; // teacherId -> { uid, displayName }

  for (const t of TEACHERS) {
    const email = `prof.${t.lastName.toLowerCase().replace(/\s+/g, '.').normalize('NFD').replace(/[\u0300-\u036f]/g, '')}@EMG.ma`;
    const uid = await getOrCreateUser(email, t.displayName, 'StudyPlanner2026!');

    await db.collection('users').doc(uid).set({
      role: 'teacher',
      fullName: t.displayName,
      personalNumber: `PROF-${t.id.toUpperCase()}`,
      email,
      teacherClassIds: [CLASS_ID],
      photoURL: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    teacherMap[t.id] = { uid, displayName: t.displayName, email };
  }

  return teacherMap;
}

async function seedStudents() {
  console.log('\n🎓 Seeding students...');
  const studentUids = [];

  for (const s of STUDENTS) {
    const fullName = `${s.firstName} ${s.lastName}`;
    const email = generateEmail(s.firstName, s.lastName);
    const password = `EMG${s.password}`;
    const uid = await getOrCreateUser(email, fullName, password);

    await db.collection('users').doc(uid).set({
      role: 'student',
      fullName,
      personalNumber: `GINF2-${String(s.n).padStart(2, '0')}`,
      email,
      classId: CLASS_ID,
      photoURL: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    studentUids.push(uid);
  }

  return studentUids;
}

async function seedClass(teacherMap, studentUids) {
  console.log('\n🏫 Seeding class...');

  // Create class document
  await db.collection('classes').doc(CLASS_ID).set({
    name: CLASS_NAME,
    createdAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  console.log(`  ✓ Class: ${CLASS_NAME}`);

  // Seed subjects
  console.log('  📖 Subjects:');
  for (const sub of SUBJECTS) {
    const teacher = sub.teacherId ? teacherMap[sub.teacherId] : null;
    await db.collection('classes').doc(CLASS_ID)
      .collection('subjects').doc(sub.id).set({
        name: sub.name,
        teacherUid: teacher?.uid || null,
        teacherName: teacher?.displayName || null,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });
    console.log(`    - ${sub.name} (${teacher?.displayName || 'Aucun enseignant'})`);
  }

  // Seed members — students
  console.log('  👥 Members:');
  for (const uid of studentUids) {
    await db.collection('classes').doc(CLASS_ID)
      .collection('members').doc(uid).set({
        role: 'student',
        joinedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
  }
  console.log(`    - ${studentUids.length} students`);

  // Seed members — teachers
  const teacherUids = new Set();
  for (const t of Object.values(teacherMap)) {
    teacherUids.add(t.uid);
  }
  for (const uid of teacherUids) {
    await db.collection('classes').doc(CLASS_ID)
      .collection('members').doc(uid).set({
        role: 'teacher',
        joinedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
  }
  console.log(`    - ${teacherUids.size} teachers`);

  // Seed timetable
  console.log('  📅 Timetable:');
  for (const slot of TIMETABLE) {
    const subject = SUBJECTS.find(s => s.id === slot.subjectId);
    const teacher = subject?.teacherId ? teacherMap[subject.teacherId] : null;

    const slotId = `${CLASS_ID}_${slot.dayOfWeek}_${slot.startMinute}`;
    await db.collection('classes').doc(CLASS_ID)
      .collection('timetableSlots').doc(slotId).set({
        dayOfWeek: slot.dayOfWeek,
        startMinute: slot.startMinute,
        endMinute: slot.endMinute,
        subjectId: slot.subjectId,
        subjectName: subject?.name || slot.subjectId,
        teacherUid: teacher?.uid || null,
        teacherName: teacher?.displayName || null,
        room: ROOM,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });

    const days = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
    const start = `${Math.floor(slot.startMinute/60)}h${String(slot.startMinute%60).padStart(2,'0')}`;
    const end = `${Math.floor(slot.endMinute/60)}h${String(slot.endMinute%60).padStart(2,'0')}`;
    console.log(`    - ${days[slot.dayOfWeek]} ${start}-${end}: ${subject?.name} (${teacher?.displayName || '-'})`);
  }
}

async function printSummary() {
  console.log('\n📊 Summary:');
  const classDoc = await db.collection('classes').doc(CLASS_ID).get();
  const subjectsSnap = await db.collection('classes').doc(CLASS_ID).collection('subjects').get();
  const membersSnap = await db.collection('classes').doc(CLASS_ID).collection('members').get();
  const slotsSnap = await db.collection('classes').doc(CLASS_ID).collection('timetableSlots').get();

  const students = membersSnap.docs.filter(d => d.data().role === 'student');
  const teachers = membersSnap.docs.filter(d => d.data().role === 'teacher');

  console.log(`  Class: ${classDoc.data()?.name}`);
  console.log(`  Subjects: ${subjectsSnap.size}`);
  console.log(`  Students: ${students.length}`);
  console.log(`  Teachers: ${teachers.length}`);
  console.log(`  Timetable slots: ${slotsSnap.size}`);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🚀 Study Planner - Real Data Seed (GINF2)');
  console.log('==========================================\n');

  try {
    const teacherMap = await seedTeachers();
    const studentUids = await seedStudents();
    await seedClass(teacherMap, studentUids);
    await printSummary();

    console.log('\n✅ Seeding complete!');
    console.log('\n💡 Student credentials:');
    for (const s of STUDENTS) {
      const email = generateEmail(s.firstName, s.lastName);
      console.log(`   ${s.firstName} ${s.lastName}: ${email} / EMG${s.password}`);
    }
    console.log('\n💡 Teacher password: StudyPlanner2026!');
  } catch (error) {
    console.error('\n❌ Error:', error);
    process.exit(1);
  }
}

main();
