import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';
const VALID_CONDITIONS = new Set([
  'stable',
  'critical',
  'unconscious',
  'recovering',
  'deceased',
]);
const VALID_ACTIONS = new Set([
  'cpr',
  'aed',
  'bleeding',
  'fracture',
  'positioning',
]);

/**
 * Records a per-responder intervention report after arrival. One doc
 * per (emergencyId, uid). Only callers in `emergencies.acceptedBy` may
 * write. Completion bumps reliability +2 (on top of the arrival bonus)
 * as a small reward for closing the loop.
 */
export const recordIntervention = onCall(
  { region: REGION, cors: true },
  async (request) => {
    if (!request.auth?.token?.certified) {
      throw new HttpsError('permission-denied', 'Not certified');
    }
    const { emergencyId, condition, actions, notes } = (request.data ??
      {}) as {
      emergencyId?: string;
      condition?: string;
      actions?: string[];
      notes?: string;
    };
    if (!emergencyId) {
      throw new HttpsError('invalid-argument', 'emergencyId required');
    }
    if (!condition || !VALID_CONDITIONS.has(condition)) {
      throw new HttpsError('invalid-argument', 'invalid condition');
    }
    const safeActions = (actions ?? []).filter((a) => VALID_ACTIONS.has(a));
    const uid = request.auth.uid;
    const db = admin.firestore();
    const caseSnap = await db
      .collection('emergencies')
      .doc(emergencyId)
      .get();
    if (!caseSnap.exists) {
      throw new HttpsError('not-found', 'Emergency not found');
    }
    const acceptedBy = Array.isArray(caseSnap.get('acceptedBy'))
      ? (caseSnap.get('acceptedBy') as string[])
      : [];
    if (!acceptedBy.includes(uid)) {
      throw new HttpsError(
        'failed-precondition',
        'Caller did not accept this emergency',
      );
    }
    await db
      .collection('intervention_reports')
      .doc(`${emergencyId}_${uid}`)
      .set({
        emergencyId,
        uid,
        condition,
        actions: safeActions,
        notes: notes ?? '',
        createdAt: FieldValue.serverTimestamp(),
      });
    // Small reliability bump for closing the loop.
    await db.collection('users').doc(uid).set(
      {
        reliability: FieldValue.increment(2),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    logger.info('Intervention recorded', { emergencyId, uid, condition });
    return { ok: true };
  },
);
