/**
 * Manually grant dispatcher custom claim to a user.
 *
 * Setup (once):
 *   1. Download a service account JSON from Firebase Console
 *      (Project Settings → Service accounts → Generate new private key)
 *   2. Save it somewhere safe (do NOT commit)
 *   3. Find the target user's UID in Firebase Console → Authentication
 *
 * Run:
 *   cd firebase/functions
 *   npx ts-node ../scripts/assignDispatcher.ts <UID> /path/to/service-account.json
 */
import * as admin from 'firebase-admin';

async function main() {
  const uid = process.argv[2];
  const keyPath = process.argv[3];
  if (!uid || !keyPath) {
    console.error('Usage: assignDispatcher.ts <UID> <service-account-json>');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(require(keyPath)),
  });

  await admin.auth().setCustomUserClaims(uid, { role: 'dispatcher' });
  console.log(`dispatcher claim set on uid=${uid}`);
  console.log('User must sign out and back in for the claim to take effect.');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
