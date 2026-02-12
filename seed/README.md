# Study Planner - Seed Script

This script populates Firebase (Auth + Firestore) with demo data for testing.

## Prerequisites

1. **Firebase Admin SDK service account key**:
   - Go to Firebase Console > Project Settings > Service accounts
   - Click "Generate new private key"
   - Save as `serviceAccountKey.json` in this folder

2. **Node.js 18+**

## Setup

```bash
cd seed
npm install
```

## Usage

```bash
npm run seed
```

## What Gets Created

### Classes (3)
- **GI** - Génie Informatique
- **GE** - Génie Électrique
- **GC** - Génie Civil

### Users
- **~25 students per class** (75 total)
- **18 teachers** (6 subjects × 3 classes, some shared)
- All emails: `firstname.lastname@EMG.ma`
- Default password: `StudyPlanner2026!`

### Subjects (6 per class)
1. Mathématiques
2. Physique
3. Informatique
4. Anglais
5. Communication
6. Spécialité (varies by class)

### Timetable
- Weekly slots (Mon-Fri)
- 4-5 slots per day
- 2-hour blocks

### Assessments
- 2 assessments per class for current week
- Types: exam, quiz, project

## Idempotency

The script is **idempotent**:
- Users are created/updated by email (no duplicates)
- Documents are merged (not overwritten)
- Running twice produces the same result

## Special Accounts

| Name | Email | Role | Class |
|------|-------|------|-------|
| Amine Oukhouya | amine.oukhouya@EMG.ma | student | GI |

## Verification

After running, the script prints:
- Total users created/updated
- Classes count
- Subjects per class
- Students per class
- Teachers count
- Timetable slots count
- Assessments count
