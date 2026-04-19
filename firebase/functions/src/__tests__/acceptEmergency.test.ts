/**
 * Tests for the `acceptEmergency` callable.
 *
 * These tests require the Firestore emulator. Run via:
 *   firebase emulators:exec --only firestore \
 *     "cd firebase/functions && npm test"
 *
 * When FIRESTORE_EMULATOR_HOST is set, the firebase-admin SDK routes all
 * reads/writes to localhost:8080 and does not contact production.
 */

import functionsTest from 'firebase-functions-test';
import * as admin from 'firebase-admin';

// firebase-functions-test needs to be imported BEFORE the function modules
// so the initializeApp() hook inside src/index.ts uses emulator creds.
// We use the "offline" invocation form: no project config passed.
const tester = functionsTest();

// Point to the Firestore emulator. `firebase emulators:exec` sets this env
// var automatically, but we also default it for direct `npm test` runs.
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? 'localhost:8080';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? 'demo-klinik-nabiz';

if (!admin.apps.length) {
  admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });
}

// Import the module under test AFTER admin is initialised above. Using
// require so the TS compiler doesn't hoist it before init.
// eslint-disable-next-line @typescript-eslint/no-var-requires
const { acceptEmergency } = require('../emergency');

const wrapped = tester.wrap(acceptEmergency);

const db = admin.firestore();

interface SeedOpts {
  id?: string;
  status?: 'open' | 'accepted' | 'cancelled' | 'expired' | 'resolved';
  acceptedBy?: string[];
}

async function seedEmergency(opts: SeedOpts = {}): Promise<string> {
  const id =
    opts.id ?? `em_${Date.now()}_${Math.floor(Math.random() * 1e6)}`;
  await db
    .collection('emergencies')
    .doc(id)
    .set({
      type: 'injury',
      severity: 'serious',
      status: opts.status ?? 'open',
      acceptedBy: opts.acceptedBy ?? [],
      notifiedUids: [],
      location: new admin.firestore.GeoPoint(41.0082, 28.9784),
      address: 'Test',
      region: { country: 'TR', city: 'Istanbul', district: 'Kadıköy' },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  return id;
}

async function seedUser(uid: string): Promise<void> {
  await db
    .collection('users')
    .doc(uid)
    .set(
      {
        stats: { interventions: 0, educationPoints: 0 },
        fcmTokens: [],
        active: true,
        available: true,
      },
      { merge: true },
    );
}

function certifiedAuth(uid: string) {
  return {
    auth: {
      uid,
      token: { certified: true, firebase: { sign_in_provider: 'phone' } },
    },
  } as unknown;
}

afterAll(async () => {
  tester.cleanup();
  await admin.app().delete();
});

describe('acceptEmergency', () => {
  test('rejects uncertified callers', async () => {
    const id = await seedEmergency();
    await expect(
      wrapped({
        data: { emergencyId: id },
        auth: { uid: 'nope', token: {} },
      }),
    ).rejects.toMatchObject({ code: 'permission-denied' });
  });

  test('first accept flips status to accepted and increments stats', async () => {
    const id = await seedEmergency();
    await seedUser('volA');

    await wrapped({
      data: { emergencyId: id },
      ...(certifiedAuth('volA') as object),
    });

    const caseSnap = await db.collection('emergencies').doc(id).get();
    expect(caseSnap.get('status')).toBe('accepted');
    expect(caseSnap.get('acceptedBy')).toEqual(['volA']);
    expect(caseSnap.get('acceptedAt')).toBeTruthy();

    const userSnap = await db.collection('users').doc('volA').get();
    expect(userSnap.get('stats.interventions')).toBe(1);
  });

  test('second unique accept adds to array without re-flipping status', async () => {
    const id = await seedEmergency();
    await seedUser('volA');
    await seedUser('volB');

    await wrapped({
      data: { emergencyId: id },
      ...(certifiedAuth('volA') as object),
    });
    await wrapped({
      data: { emergencyId: id },
      ...(certifiedAuth('volB') as object),
    });

    const caseSnap = await db.collection('emergencies').doc(id).get();
    expect(caseSnap.get('status')).toBe('accepted');
    const accepted = caseSnap.get('acceptedBy') as string[];
    expect(accepted).toHaveLength(2);
    expect(accepted).toContain('volA');
    expect(accepted).toContain('volB');

    expect(
      (await db.collection('users').doc('volA').get()).get(
        'stats.interventions',
      ),
    ).toBe(1);
    expect(
      (await db.collection('users').doc('volB').get()).get(
        'stats.interventions',
      ),
    ).toBe(1);
  });

  test('double-accept by same uid is idempotent (no duplicate, no double-count)', async () => {
    const id = await seedEmergency();
    await seedUser('volA');

    await wrapped({
      data: { emergencyId: id },
      ...(certifiedAuth('volA') as object),
    });
    await wrapped({
      data: { emergencyId: id },
      ...(certifiedAuth('volA') as object),
    });

    const caseSnap = await db.collection('emergencies').doc(id).get();
    expect(caseSnap.get('acceptedBy')).toEqual(['volA']);

    const userSnap = await db.collection('users').doc('volA').get();
    expect(userSnap.get('stats.interventions')).toBe(1);
  });

  test('rejects accept on a closed case', async () => {
    const id = await seedEmergency({ status: 'cancelled' });
    await seedUser('volA');

    await expect(
      wrapped({
        data: { emergencyId: id },
        ...(certifiedAuth('volA') as object),
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
