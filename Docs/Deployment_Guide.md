# Deployment Guide

## Prerequisites

- Node.js 18+
- Flutter 3.38+
- Firebase CLI (`npm install -g firebase-tools`)
- Android SDK (for release builds)

---

## 1. Firebase Project Setup

### Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project: "StudyPlanner"
3. Enable Google Analytics (optional)

### Configure Services

#### Authentication
1. Go to Authentication > Sign-in method
2. Enable "Email/Password" provider

#### Firestore
1. Go to Firestore Database
2. Create database in production mode
3. Choose region (europe-west1 recommended for Morocco)

#### Storage
1. Go to Storage
2. Create bucket in production mode

#### Cloud Messaging (FCM)
1. Go to Project Settings > Cloud Messaging
2. Note the Server Key (for testing)

---

## 2. Deploy Security Rules

```bash
cd "c:\Users\Amine\OneDrive\Desktop\StudyPlanner Apps"

# Login to Firebase
firebase login

# Set project
firebase use --add
# Select your project

# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Deploy Firestore indexes
firebase deploy --only firestore:indexes
```

---

## 3. Deploy Cloud Functions

```bash
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy functions
npm run deploy
# Or: firebase deploy --only functions
```

### Deployed Functions
- `createAttendanceSession` - Teacher opens QR session
- `submitAttendance` - Student submits attendance
- `createAssessment` - Teacher creates assessment
- `updateAssessment` - Teacher updates assessment
- `cancelAssessment` - Teacher cancels assessment
- `onAssessmentCreated` - FCM trigger for new assessment
- `onAssessmentUpdated` - FCM trigger for assessment changes

---

## 4. Seed Demo Data

```bash
cd seed

# Install dependencies
npm install

# Get service account key from Firebase Console
# Project Settings > Service accounts > Generate new private key
# Save as serviceAccountKey.json

# Run seed script
npm run seed
```

### Seeded Data
- 3 classes (GI, GE, GC)
- 75 students (25 per class)
- 11 teachers
- 6 subjects per class
- Weekly timetable
- Sample assessments

### Test Account
- Email: `amine.oukhouya@EMG.ma`
- Password: `StudyPlanner2026!`
- Role: Student (GI class)

---

## 5. Configure Flutter App

### Android Configuration

1. Download `google-services.json` from Firebase Console:
   - Project Settings > Your apps > Android
   - Register app with package name: `ma.emg.studyplanner.study_planner`
   - Download config file

2. Place in `android/app/google-services.json`

3. Update `lib/app/firebase_options.dart` with your project values (if using flutterfire configure)

### Verify Configuration

```bash
flutter pub get
flutter analyze
flutter test
```

---

## 6. Build Release APK

```bash
# Debug build (for testing)
flutter build apk --debug

# Release build (for distribution)
flutter build apk --release
```

### Output Locations
- Debug: `build/app/outputs/flutter-apk/app-debug.apk`
- Release: `build/app/outputs/flutter-apk/app-release.apk`

### Release Signing (Production)
For Play Store distribution, configure signing in `android/app/build.gradle.kts`:

```kotlin
signingConfigs {
    create("release") {
        storeFile = file("keystore.jks")
        storePassword = "your-password"
        keyAlias = "your-alias"
        keyPassword = "your-key-password"
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
        // ...
    }
}
```

---

## 7. Post-Deployment Verification

### Backend
- [ ] Firestore rules deployed (check Firebase Console)
- [ ] Storage rules deployed
- [ ] Cloud Functions deployed and active
- [ ] FCM configured

### App
- [ ] Login works with seeded accounts
- [ ] Data loads from Firestore
- [ ] Attendance QR flow works
- [ ] Push notifications received

---

## Troubleshooting

### Common Issues

**"Firebase not initialized"**
- Ensure `google-services.json` is in `android/app/`
- Run `flutter clean && flutter pub get`

**Cloud Functions not triggering**
- Check Firebase Console > Functions > Logs
- Verify function deployed successfully
- Check Firestore document paths match triggers

**FCM not working**
- Verify FCM is enabled in Firebase Console
- Check device token is saved in Firestore
- Test with Firebase Console > Cloud Messaging > Send test message

**Permission denied errors**
- Review Firestore rules in Firebase Console
- Check user authentication state
- Verify class membership in Firestore

---

## Monitoring

### Firebase Console
- Authentication: Monitor active users
- Firestore: Monitor read/write operations
- Functions: Monitor invocations and errors
- Cloud Messaging: Monitor delivery rates

### Recommended Alerts
- Function errors > 10/hour
- Firestore read operations > 50K/day
- Authentication failures > 100/day
