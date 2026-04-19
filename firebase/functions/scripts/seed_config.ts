/**
 * Seed app_config/wave_plan + app_config/competency into the running
 * Firebase emulator. Run from firebase/functions:
 *   npm run seed:config
 *
 * Dispatcher-editable config lives in Firestore so tweaks don't require
 * redeploys. This script writes the defaults; subsequent dispatcher
 * edits via the admin panel (future) or emulator UI are respected.
 */
import * as admin from 'firebase-admin';

process.env.FIREBASE_AUTH_EMULATOR_HOST =
  process.env.FIREBASE_AUTH_EMULATOR_HOST ?? '127.0.0.1:9099';
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080';
process.env.GCLOUD_PROJECT =
  process.env.GCLOUD_PROJECT ?? 'ilk-yardim-3465';

admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT });

const wavePlan = {
  critical: [
    { radiusKm: 5, maxRecipients: 9999, timeoutSec: 120 },
    { radiusKm: 10, maxRecipients: 9999, timeoutSec: 180 },
  ],
  serious: [
    { radiusKm: 3, maxRecipients: 5, timeoutSec: 60 },
    { radiusKm: 5, maxRecipients: 10, timeoutSec: 120 },
    { radiusKm: 15, maxRecipients: 9999, timeoutSec: 180 },
  ],
  minor: [
    { radiusKm: 2, maxRecipients: 3, timeoutSec: 90 },
    { radiusKm: 3, maxRecipients: 5, timeoutSec: 180 },
  ],
};

const competency = {
  certLevels: {
    paramedic: 100,
    als: 90,
    bls: 75,
    advanced_first_aid: 60,
    basic_first_aid: 40,
  },
  matrix: {
    heart_attack: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 60,
      basic_first_aid: 30,
    },
    breathing_difficulty: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 65,
      basic_first_aid: 40,
    },
    choking: {
      paramedic: 95,
      als: 90,
      bls: 85,
      advanced_first_aid: 80,
      basic_first_aid: 70,
    },
    injury: {
      paramedic: 95,
      als: 90,
      bls: 80,
      advanced_first_aid: 80,
      basic_first_aid: 65,
    },
    traffic_accident: {
      paramedic: 100,
      als: 90,
      bls: 80,
      advanced_first_aid: 70,
      basic_first_aid: 50,
    },
    poisoning: {
      paramedic: 100,
      als: 95,
      bls: 75,
      advanced_first_aid: 60,
      basic_first_aid: 40,
    },
    fall: {
      paramedic: 90,
      als: 85,
      bls: 75,
      advanced_first_aid: 70,
      basic_first_aid: 55,
    },
    unconsciousness: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 60,
      basic_first_aid: 30,
    },
    other: {
      paramedic: 80,
      als: 75,
      bls: 70,
      advanced_first_aid: 60,
      basic_first_aid: 50,
    },
  },
  aliases: {
    'İleri İlkyardım Sertifikası': 'advanced_first_aid',
    'Temel İlkyardım Sertifikası': 'basic_first_aid',
    'İleri Yaşam Desteği': 'als',
    'Temel Yaşam Desteği': 'bls',
    Paramedik: 'paramedic',
  },
};

async function main() {
  const db = admin.firestore();
  await db.collection('app_config').doc('wave_plan').set(wavePlan);
  await db
    .collection('app_config')
    .doc('competency')
    .set({
      ...competency,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  console.log('✓ Config seeded: app_config/{wave_plan, competency}');
  process.exit(0);
}

main().catch((e) => {
  console.error('seed_config failed:', e);
  process.exit(1);
});
