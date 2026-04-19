/**
 * Creates (or refreshes) an email/password dispatcher account in the
 * Auth emulator so the admin panel's Login.tsx (which uses
 * signInWithEmailAndPassword) has a working test account.
 *
 *   Email    : dispatcher@klinik.dev
 *   Password : Dispatcher!2026
 *
 * Run from firebase/functions:
 *   npm run seed:admin-login
 */
import * as admin from 'firebase-admin';

process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
process.env.GCLOUD_PROJECT =
  process.env.GCLOUD_PROJECT ?? 'demo-klinik-nabiz';

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const EMAIL = 'dispatcher@klinik.dev';
const PASSWORD = 'Dispatcher!2026';

async function main() {
  let uid: string;
  try {
    const existing = await admin.auth().getUserByEmail(EMAIL);
    uid = existing.uid;
    await admin.auth().updateUser(uid, {
      password: PASSWORD,
      emailVerified: true,
    });
    console.log('> refreshed existing user', uid);
  } catch {
    const created = await admin.auth().createUser({
      email: EMAIL,
      password: PASSWORD,
      displayName: 'Test Dispatcher (Email)',
      emailVerified: true,
    });
    uid = created.uid;
    console.log('> created new user', uid);
  }

  await admin.auth().setCustomUserClaims(uid, {
    role: 'dispatcher',
    certified: true,
  });

  // Mirror into Firestore users doc so the admin panel's Volunteers page
  // sees the role field too.
  await admin
    .firestore()
    .collection('users')
    .doc(uid)
    .set(
      {
        phone: EMAIL,
        fullName: 'Test Dispatcher',
        role: 'dispatcher',
        roleLabel: 'Dispatcher',
        region: { country: 'TR', city: 'istanbul', district: 'kadikoy' },
        active: true,
        available: true,
        stats: { interventions: 0, educationPoints: 0 },
        badges: [],
        fcmTokens: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

  console.log('');
  console.log('✓ Admin panel login ready.');
  console.log('  Email    :', EMAIL);
  console.log('  Password :', PASSWORD);
  console.log('  UID      :', uid);
  console.log('');
  console.log('  Open http://localhost:5173 and sign in.');
  process.exit(0);
}

main().catch((e) => {
  console.error('seed_admin_login failed:', e);
  process.exit(1);
});
