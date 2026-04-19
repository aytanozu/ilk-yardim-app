import * as admin from 'firebase-admin';
import { Timestamp } from 'firebase-admin/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';

/**
 * Daily scheduled cleanup to keep ancillary collections bounded.
 *
 * Currently scrubs:
 *   - `rate_limits/{key}` docs idle for > 24h. The sliding-window
 *     limiter prunes expired entries inside each doc on every call,
 *     but docs created by users who never return would otherwise
 *     accumulate indefinitely.
 *
 * Extend this function rather than adding more cron handlers so the
 * scheduler quota stays predictable.
 */
export const cleanupRateLimits = onSchedule(
  { region: REGION, schedule: 'every 24 hours' },
  async () => {
    const db = admin.firestore();
    const cutoff = Timestamp.fromDate(
      new Date(Date.now() - 24 * 60 * 60 * 1000),
    );

    let scanned = 0;
    let deleted = 0;
    const pageSize = 500;
    let last: FirebaseFirestore.QueryDocumentSnapshot | null = null;

    while (true) {
      let q = db
        .collection('rate_limits')
        .where('updatedAt', '<', cutoff)
        .orderBy('updatedAt')
        .limit(pageSize);
      if (last) q = q.startAfter(last);

      const snap = await q.get();
      if (snap.empty) break;

      const batch = db.batch();
      for (const doc of snap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();

      scanned += snap.size;
      deleted += snap.size;
      last = snap.docs[snap.docs.length - 1];
      if (snap.size < pageSize) break;
    }

    logger.info('cleanupRateLimits done', { scanned, deleted });
  },
);
