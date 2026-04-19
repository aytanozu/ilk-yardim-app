import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';
const BONUS_ON_TIME = 2;
const PENALTY_NO_SHOW = -5;

/**
 * Adjust `users/{uid}.reliability` when an emergency transitions into a
 * terminal state. Runs once per case lifecycle; idempotent because we
 * watch the exact status transition into resolved/expired/cancelled.
 *
 *  - acceptors WITH `arrivedAt` → +2 (cap 100)
 *  - acceptors WITHOUT `arrivedAt` → -5 (floor 0) [no-show]
 *  - notified but never accepted → neutral
 *
 * Gamers accepting everything then ghosting naturally drop below 50
 * over a handful of cases; the weighted dispatch scorer de-prioritizes
 * them downstream.
 */
export const onEmergencyClosedReliability = onDocumentUpdated(
  { region: REGION, document: 'emergencies/{id}' },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;

    const terminal = new Set(['resolved', 'expired', 'cancelled']);
    const wasOpen = !terminal.has((before?.status as string) ?? 'open');
    const isClosed = terminal.has(after.status as string);
    if (!(wasOpen && isClosed)) return;

    const acceptedBy = Array.isArray(after.acceptedBy)
      ? (after.acceptedBy as string[])
      : [];
    if (!acceptedBy.length) return;

    const arrived = new Set<string>();
    if (after.arrivedBy) arrived.add(after.arrivedBy as string);

    const db = admin.firestore();
    const batch = db.batch();
    for (const uid of acceptedBy) {
      const delta = arrived.has(uid) ? BONUS_ON_TIME : PENALTY_NO_SHOW;
      batch.set(
        db.collection('users').doc(uid),
        {
          reliability: FieldValue.increment(delta),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
    await batch.commit();

    // Second pass to clamp 0..100 (FieldValue.increment has no bounds).
    // Best-effort; a stale read is fine since next trigger re-clamps.
    const snaps = await Promise.all(
      acceptedBy.map((uid) => db.collection('users').doc(uid).get()),
    );
    const clamps = db.batch();
    let clampWrites = 0;
    for (const snap of snaps) {
      const val = (snap.get('reliability') as number | undefined) ?? 50;
      if (val > 100) {
        clamps.update(snap.ref, { reliability: 100 });
        clampWrites++;
      } else if (val < 0) {
        clamps.update(snap.ref, { reliability: 0 });
        clampWrites++;
      }
    }
    if (clampWrites > 0) await clamps.commit();

    logger.info('Reliability updated', {
      emergencyId: event.params.id,
      acceptedCount: acceptedBy.length,
      arrivedCount: arrived.size,
    });
  },
);
