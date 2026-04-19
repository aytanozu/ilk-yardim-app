import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

/**
 * Simple Firestore-backed sliding window rate limiter.
 *
 * Stores a ring buffer of recent call timestamps at `rate_limits/{key}`.
 * On each call we drop anything older than `windowMs`, then reject if
 * the remaining count exceeds `max`. Atomicity is achieved with a
 * transaction so two concurrent calls can't both slip past the limit.
 *
 * The implementation is intentionally modest: it's a soft cost-control
 * shield against bursty abuse, not a cryptographic guarantee. Real DDoS
 * protection belongs at the load-balancer / Cloud Armor layer.
 */
export async function assertWithinRateLimit(
  key: string,
  opts: { max: number; windowMs: number; reasonCode?: string },
): Promise<void> {
  const db = admin.firestore();
  const ref = db.collection('rate_limits').doc(key);
  const now = Date.now();
  const cutoff = now - opts.windowMs;

  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const raw = (snap.get('hits') as number[] | undefined) ?? [];
      const recent = raw.filter((t) => t > cutoff);
      if (recent.length >= opts.max) {
        throw new HttpsError(
          'resource-exhausted',
          opts.reasonCode ?? 'rate_limited',
        );
      }
      recent.push(now);
      tx.set(ref, {
        hits: recent,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (e) {
    if (e instanceof HttpsError) throw e;
    // Transaction failures (contention / transient) should not wedge the
    // user — we log and let the call proceed rather than erring.
    // eslint-disable-next-line no-console
    console.warn('rate_limit tx failed', { key, err: (e as Error).message });
  }
}

/** Safer key: replace characters Firestore doc ids reject. */
export function sanitizeKey(raw: string): string {
  return raw.replace(/[^A-Za-z0-9_\-+]/g, '_').slice(0, 200);
}
