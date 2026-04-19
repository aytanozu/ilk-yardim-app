import * as admin from 'firebase-admin';
import { FieldValue } from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';

/**
 * Records a quiz attempt server-side. Clients previously wrote directly
 * to `users/{uid}.stats.educationPoints`, but with Firestore rules now
 * locking that field to server-only writes, all attempt persistence is
 * funneled through this callable.
 *
 * Points rule: `score * 10`. The attempt id is `{uid}_{quizId}` so a
 * retry overwrites the previous attempt for the same quiz. Stats only
 * increment when the new score beats the previous best, so retaking
 * a quiz can't farm points indefinitely.
 */
export const recordQuizAttempt = onCall(
  { region: REGION, cors: true },
  async (request) => {
    if (!request.auth?.token?.certified) {
      throw new HttpsError('permission-denied', 'Not certified');
    }
    const uid = request.auth.uid;
    const quizId = request.data?.quizId as string | undefined;
    const score = request.data?.score as number | undefined;
    const answers = (request.data?.answers ?? {}) as Record<string, number>;
    if (!quizId || typeof score !== 'number') {
      throw new HttpsError('invalid-argument', 'quizId + score required');
    }
    if (!Number.isInteger(score) || score < 0 || score > 100) {
      throw new HttpsError('invalid-argument', 'score must be int 0..100');
    }

    const db = admin.firestore();
    const attemptRef = db
      .collection('quiz_attempts')
      .doc(`${uid}_${quizId}`);
    const userRef = db.collection('users').doc(uid);

    const delta = await db.runTransaction(async (tx) => {
      const prev = await tx.get(attemptRef);
      const prevScore = prev.exists ? (prev.get('score') as number) ?? 0 : 0;
      const improvement = Math.max(0, score - prevScore);

      tx.set(attemptRef, {
        uid,
        quizId,
        answers,
        score,
        completedAt: FieldValue.serverTimestamp(),
      });

      if (improvement > 0) {
        tx.set(
          userRef,
          {
            stats: {
              educationPoints: FieldValue.increment(
                improvement * 10,
              ),
            },
          },
          { merge: true },
        );
      }

      return { awarded: improvement * 10, improvement };
    });

    logger.info('quiz attempt recorded', {
      uid,
      quizId,
      score,
      awarded: delta.awarded,
    });
    return { ok: true, awarded: delta.awarded };
  },
);
