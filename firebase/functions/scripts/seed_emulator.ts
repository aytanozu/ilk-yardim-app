/**
 * Emulator-only seed. One-shot setup for a fresh `firebase emulators:start`:
 *
 *   - Creates an Auth user for a test phone (bypasses SMS — emulator feature)
 *   - Grants `role: 'dispatcher'` custom claim so admin panel login works
 *   - Writes `certified_phones/{E164}` so the mobile app's checkCertifiedPhone
 *     gate passes
 *   - Writes `users/{uid}` with stats + region + available=true
 *   - Seeds one open emergency near Kadıköy so the map has content
 *   - Seeds a basic quiz so the training screen isn't empty
 *
 * Prereq: `firebase emulators:start` running locally. The Firebase Admin SDK
 * auto-routes to the emulator when FIREBASE_AUTH_EMULATOR_HOST and
 * FIRESTORE_EMULATOR_HOST are set — this script sets them itself so you can
 * invoke it with no env setup:
 *
 *     cd firebase/functions
 *     npx ts-node ../seed/seed_emulator.ts
 *
 * Rerunning is idempotent — existing docs are overwritten with merge:true.
 */
import * as admin from 'firebase-admin';

process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
process.env.GCLOUD_PROJECT =
  process.env.GCLOUD_PROJECT ?? 'demo-klinik-nabiz';

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const DISPATCHER_PHONE = '+905551112233';
const SECOND_VOLUNTEER_PHONE = '+905554445566';

async function ensureAuthUser(phone: string): Promise<string> {
  try {
    const existing = await admin.auth().getUserByPhoneNumber(phone);
    return existing.uid;
  } catch {
    const created = await admin.auth().createUser({ phoneNumber: phone });
    return created.uid;
  }
}

async function seedCertifiedPhone(
  phone: string,
  fullName: string,
): Promise<void> {
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 3 * 365 * 24 * 60 * 60 * 1000),
  );
  await admin
    .firestore()
    .collection('certified_phones')
    .doc(phone)
    .set(
      {
        fullName,
        certificateType: 'İleri İlkyardım Sertifikası',
        issuer: 'Sağlık Bakanlığı Onaylı',
        expiresAt,
        region: { country: 'TR', city: 'istanbul', district: 'kadikoy' },
        roleLabel: 'Gönüllü',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function seedUserDoc(uid: string, phone: string, fullName: string) {
  // Kadıköy-ish coordinates so the Istanbul map has a pin.
  const lat = 40.9903 + (Math.random() - 0.5) * 0.01;
  const lng = 29.0275 + (Math.random() - 0.5) * 0.01;
  await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .set(
      {
        phone,
        fullName,
        region: { country: 'TR', city: 'istanbul', district: 'kadikoy' },
        roleLabel: 'Gönüllü',
        stats: { interventions: 0, educationPoints: 0 },
        badges: [],
        fcmTokens: [],
        active: true,
        available: true,
        notificationPrefs: { criticalOnly: false },
        lastLocation: new admin.firestore.GeoPoint(lat, lng),
        certificate: {
          type: 'İleri İlkyardım Sertifikası',
          issuer: 'Sağlık Bakanlığı Onaylı',
          expiresAt: admin.firestore.Timestamp.fromDate(
            new Date(Date.now() + 3 * 365 * 24 * 60 * 60 * 1000),
          ),
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
}

async function seedSampleEmergency(dispatcherUid: string) {
  const db = admin.firestore();
  // Stable id so re-running the seed overwrites instead of accumulating.
  const id = 'seed_sample_open_case';
  await db
    .collection('emergencies')
    .doc(id)
    .set({
      type: 'injury',
      severity: 'serious',
      location: new admin.firestore.GeoPoint(40.99, 29.03),
      geohash: 'sxk97',
      address: 'Fenerbahçe Parkı, Kadıköy',
      description: 'Koşu parkurunda düşen gönüllü, diz kanaması',
      status: 'open',
      region: { country: 'TR', city: 'istanbul', district: 'kadikoy' },
      hazards: [],
      waveLevel: 0,
      acceptedBy: [],
      notifiedUids: [],
      createdBy: dispatcherUid,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastWaveAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function seedQuiz() {
  const quizRef = admin
    .firestore()
    .collection('quizzes')
    .doc('basic_life_support');
  await quizRef.set(
    {
      title: 'Temel Yaşam Desteği',
      categoryId: 'basic',
      questionCount: 3,
    },
    { merge: true },
  );

  const existing = await quizRef.collection('questions').limit(1).get();
  if (!existing.empty) return;

  const qs = [
    {
      text: 'Bilinci kapalı bir yetişkinde solunum kontrolü kaç saniye süreyle yapılmalıdır?',
      options: ['5 saniye', '10 saniye', '15 saniye', '20 saniye'],
      correctIndex: 1,
      order: 0,
    },
    {
      text: 'Yetişkin bir hastada göğüs kompresyonları dakikada kaç sıklıkta yapılmalıdır?',
      options: ['60-80', '80-100', '100-120', '120-140'],
      correctIndex: 2,
      order: 1,
    },
    {
      text: 'Kalp masajı derinliği yetişkinde kaç cm olmalıdır?',
      options: ['2-3 cm', '3-4 cm', '5-6 cm', '7-8 cm'],
      correctIndex: 2,
      order: 2,
    },
  ];
  for (const q of qs) {
    await quizRef.collection('questions').add(q);
  }
}

async function main() {
  console.log('> seeding emulator at', process.env.FIRESTORE_EMULATOR_HOST);

  // Dispatcher (also certified so they can sign in as a volunteer if needed)
  const dispatcherUid = await ensureAuthUser(DISPATCHER_PHONE);
  await admin
    .auth()
    .setCustomUserClaims(dispatcherUid, {
      role: 'dispatcher',
      certified: true,
    });
  await seedCertifiedPhone(DISPATCHER_PHONE, 'Test Dispatcher');
  await seedUserDoc(dispatcherUid, DISPATCHER_PHONE, 'Test Dispatcher');

  // Second volunteer (volunteer-only) so multi-accept has someone to test.
  const volUid = await ensureAuthUser(SECOND_VOLUNTEER_PHONE);
  await admin.auth().setCustomUserClaims(volUid, { certified: true });
  await seedCertifiedPhone(SECOND_VOLUNTEER_PHONE, 'Test Gönüllü 2');
  await seedUserDoc(volUid, SECOND_VOLUNTEER_PHONE, 'Test Gönüllü 2');

  await seedSampleEmergency(dispatcherUid);
  await seedQuiz();

  console.log('');
  console.log('✓ Seed complete.');
  console.log('  Dispatcher phone :', DISPATCHER_PHONE, '(uid:', dispatcherUid, ')');
  console.log('  Volunteer phone  :', SECOND_VOLUNTEER_PHONE, '(uid:', volUid, ')');
  console.log('');
  console.log('  In the emulator auth UI (http://localhost:4000) you can');
  console.log('  sign in with these phones; SMS codes are shown in the UI.');
  process.exit(0);
}

main().catch((e) => {
  console.error('seed failed:', e);
  process.exit(1);
});
