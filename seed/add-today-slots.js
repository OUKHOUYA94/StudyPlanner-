/**
 * Adds timetable slots for TODAY (Sunday) for all GINF2 teachers.
 * For testing the QR attendance feature.
 */

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { readFileSync, existsSync, writeFileSync, unlinkSync } from 'fs';
import { homedir, tmpdir } from 'os';
import { join } from 'path';

// ── Firebase init (CLI credentials) ──
const PROJECT_ID = 'studyplanner-dev-emg';
const CLI_CLIENT_ID = '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com';
const CLI_CLIENT_SECRET = 'j9iVZfS8kkCEFUPaAeJV0sAi';
let tempAdcPath = null;

const configPath = join(homedir(), '.config', 'configstore', 'firebase-tools.json');
if (!existsSync(configPath)) { console.error('❌ Firebase CLI not logged in!'); process.exit(1); }
const cliConfig = JSON.parse(readFileSync(configPath, 'utf8'));
const refreshToken = cliConfig.tokens?.refresh_token;
if (!refreshToken) { console.error('❌ No refresh token.'); process.exit(1); }
tempAdcPath = join(tmpdir(), `firebase-adc-${Date.now()}.json`);
writeFileSync(tempAdcPath, JSON.stringify({
  type: 'authorized_user',
  client_id: CLI_CLIENT_ID,
  client_secret: CLI_CLIENT_SECRET,
  refresh_token: refreshToken,
}));
process.env.GOOGLE_APPLICATION_CREDENTIALS = tempAdcPath;
initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID });

function cleanupTempAdc() {
  if (tempAdcPath && existsSync(tempAdcPath)) { try { unlinkSync(tempAdcPath); } catch {} }
}
process.on('exit', cleanupTempAdc);

const db = getFirestore();

// ── Config ──
const CLASS_ID = 'GINF2';
const ROOM = 'Salle 6';

// Today's dayOfWeek
const now = new Date();
const todayDow = now.getDay() === 0 ? 7 : now.getDay(); // JS: 0=Sun → 7
const dayNames = ['', 'Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
console.log(`📅 Today: ${dayNames[todayDow]} (dayOfWeek=${todayDow})`);

// Subjects and their teachers (from seed-real.js)
const SUBJECTS = [
  { id: 'anglais',    name: 'Anglais',                                        teacherId: 'bouraqqadi' },
  { id: 'francais',   name: 'Français',                                       teacherId: 'essalhi' },
  { id: 'poo',        name: 'Programmation Orientée Avancée',                  teacherId: 'elkhrouite' },
  { id: 'dam',        name: 'Développement des Applications Mobiles',          teacherId: 'bara' },
  { id: 'web',        name: 'Technologies avancées du Web',                    teacherId: 'khald' },
  { id: 'data_ia',    name: 'Data science et IA',                             teacherId: 'hmami' },
  { id: 'genie_log',  name: 'Génie logiciel et modélisation orientée objet',   teacherId: 'aarab' },
];

// One slot per teacher, staggered times
const SLOTS = [
  { startMinute:  8*60, endMinute: 10*60, subjectId: 'anglais'   },
  { startMinute: 10*60, endMinute: 12*60, subjectId: 'francais'  },
  { startMinute: 13*60, endMinute: 15*60, subjectId: 'poo'       },
  { startMinute: 15*60, endMinute: 17*60, subjectId: 'dam'       },
  { startMinute: 17*60, endMinute: 19*60, subjectId: 'web'       },
  { startMinute: 19*60, endMinute: 21*60, subjectId: 'data_ia'   },
  { startMinute: 21*60, endMinute: 23*60, subjectId: 'genie_log' },
];

async function main() {
  console.log(`\n🔧 Adding test timetable slots for ${dayNames[todayDow]} (GINF2)...\n`);

  // Look up teacher UIDs from subjects subcollection
  const subjectsSnap = await db.collection('classes').doc(CLASS_ID).collection('subjects').get();
  const subjectMap = {};
  for (const doc of subjectsSnap.docs) {
    subjectMap[doc.id] = doc.data();
  }

  let count = 0;
  for (const slot of SLOTS) {
    const subject = SUBJECTS.find(s => s.id === slot.subjectId);
    const subjectData = subjectMap[slot.subjectId];
    if (!subjectData) {
      console.log(`  ⚠ Subject ${slot.subjectId} not found, skipping`);
      continue;
    }

    const slotId = `${CLASS_ID}_${todayDow}_${slot.startMinute}`;
    const startH = Math.floor(slot.startMinute / 60);
    const startM = String(slot.startMinute % 60).padStart(2, '0');
    const endH = Math.floor(slot.endMinute / 60);
    const endM = String(slot.endMinute % 60).padStart(2, '0');

    await db.collection('classes').doc(CLASS_ID)
      .collection('timetableSlots').doc(slotId).set({
        dayOfWeek: todayDow,
        startMinute: slot.startMinute,
        endMinute: slot.endMinute,
        subjectId: slot.subjectId,
        subjectName: subjectData.name || subject.name,
        teacherUid: subjectData.teacherUid || null,
        teacherName: subjectData.teacherName || null,
        room: ROOM,
        createdAt: FieldValue.serverTimestamp(),
      }, { merge: true });

    console.log(`  ✓ ${startH}h${startM}-${endH}h${endM}: ${subject.name} (${subjectData.teacherName || '-'})`);
    count++;
  }

  console.log(`\n✅ Added ${count} slots for ${dayNames[todayDow]}.`);
  console.log('   Teachers can now test QR attendance on the Présences page.');
}

main().catch(e => { console.error('❌', e); process.exit(1); });
