import * as admin from 'firebase-admin';
import {
  FieldPath,
  FieldValue,
  Timestamp,
} from 'firebase-admin/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';

interface CertifiedPhoneInput {
  phoneE164: string;
  fullName: string;
  certificateId?: string;
  certificateType?: string;
  issuer?: string;
  expiresAt: string; // ISO
  region: { country: string; city: string; district: string };
  roleLabel?: string;
}

function assertDispatcher(token?: { role?: string }): void {
  if (token?.role !== 'dispatcher') {
    throw new HttpsError('permission-denied', 'dispatcher only');
  }
}

/**
 * Bulk import certified phone records. Batches 500 writes.
 */
export const bulkImportCertifiedPhones = onCall(
  { region: REGION, cors: true, timeoutSeconds: 540 },
  async (request) => {
    assertDispatcher(request.auth?.token as { role?: string } | undefined);
    const rows = request.data?.rows as CertifiedPhoneInput[] | undefined;
    if (!rows || !Array.isArray(rows) || rows.length === 0) {
      throw new HttpsError('invalid-argument', 'rows required');
    }

    const db = admin.firestore();
    let written = 0;
    for (let i = 0; i < rows.length; i += 500) {
      const batch = db.batch();
      for (const row of rows.slice(i, i + 500)) {
        if (!/^\+[1-9]\d{7,14}$/.test(row.phoneE164)) continue;
        const ref = db.collection('certified_phones').doc(row.phoneE164);
        batch.set(
          ref,
          {
            fullName: row.fullName ?? '',
            certificateId: row.certificateId ?? null,
            certificateType:
              row.certificateType ?? 'İleri İlkyardım Sertifikası',
            issuer: row.issuer ?? 'Sağlık Bakanlığı Onaylı',
            expiresAt: Timestamp.fromDate(
              new Date(row.expiresAt),
            ),
            region: row.region,
            roleLabel: row.roleLabel ?? 'Gönüllü',
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
        written++;
      }
      await batch.commit();
    }
    logger.info('bulkImportCertifiedPhones', { written });
    return { ok: true, written };
  },
);

/**
 * Dispatcher-only: close an emergency with a given reason. Fans out a
 * `case_closed` data push to notified + accepted volunteers so their
 * clients can dismiss the card.
 */
export const closeEmergency = onCall(
  { region: REGION, cors: true },
  async (request) => {
    assertDispatcher(request.auth?.token as { role?: string } | undefined);
    const emergencyId = request.data?.emergencyId as string | undefined;
    const reason = request.data?.reason as string | undefined;
    if (!emergencyId) {
      throw new HttpsError('invalid-argument', 'emergencyId required');
    }
    const allowedReasons = new Set(['cancelled', 'expired', 'resolved']);
    if (!reason || !allowedReasons.has(reason)) {
      throw new HttpsError('invalid-argument', 'invalid reason');
    }

    const db = admin.firestore();
    const ref = db.collection('emergencies').doc(emergencyId);

    // Atomic close: reject if another dispatcher already closed this
    // case, so we never silently overwrite a concurrent decision.
    const data = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Emergency not found');
      }
      const d = snap.data()!;
      const currentStatus = d.status as string;
      if (
        currentStatus === 'cancelled' ||
        currentStatus === 'expired' ||
        currentStatus === 'resolved'
      ) {
        throw new HttpsError('failed-precondition', 'Already closed');
      }
      tx.update(ref, {
        status: reason,
        closedAt: FieldValue.serverTimestamp(),
        closedBy: request.auth!.uid,
        closeReason: reason,
      });
      return d;
    });

    const rawAccepted = data.acceptedBy;
    const acceptedByList: string[] = Array.isArray(rawAccepted)
      ? (rawAccepted as string[])
      : typeof rawAccepted === 'string' && rawAccepted
        ? [rawAccepted]
        : [];

    // Clear activeEmergencyId on every acceptor so their background
    // service drops out of GPS burst mode. Done as a batched write to
    // avoid N round-trips.
    if (acceptedByList.length) {
      const batch = db.batch();
      for (const uid of acceptedByList) {
        batch.set(
          db.collection('users').doc(uid),
          {
            activeEmergencyId: FieldValue.delete(),
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }
      await batch.commit();
    }

    const peers = Array.from(
      new Set<string>([
        ...((data.notifiedUids as string[]) ?? []),
        ...acceptedByList,
      ]),
    );
    if (peers.length) {
      const tokens: string[] = [];
      for (let i = 0; i < peers.length; i += 30) {
        const chunk = peers.slice(i, i + 30);
        const snaps = await db
          .collection('users')
          .where(FieldPath.documentId(), 'in', chunk)
          .get();
        for (const d of snaps.docs) {
          const t = (d.get('fcmTokens') as string[]) ?? [];
          tokens.push(...t);
        }
      }
      if (tokens.length) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          data: { emergencyId, type: 'case_closed', reason },
          android: { priority: 'normal' },
          apns: {
            headers: {
              'apns-priority': '5',
              'apns-push-type': 'background',
            },
            payload: { aps: { 'content-available': 1 } },
          },
        });
      }
    }

    await db.collection('audit_log').add({
      action: 'close_emergency',
      actorUid: request.auth!.uid,
      emergencyId,
      reason,
      at: FieldValue.serverTimestamp(),
    });

    logger.info('Emergency closed', {
      emergencyId,
      reason,
      actor: request.auth!.uid,
    });
    return { ok: true };
  },
);

/**
 * Dispatcher-only: grant the `role: dispatcher` custom claim to a user.
 * Auth is performed via the caller's existing dispatcher claim — no
 * shared-secret needed. Bootstrapping the FIRST dispatcher still
 * requires running `firebase/scripts/assignDispatcher.ts` locally with
 * a service-account JSON.
 */
export const assignDispatcherRole = onCall(
  { region: REGION, cors: true },
  async (request) => {
    assertDispatcher(request.auth?.token as { role?: string } | undefined);
    const uid = request.data?.uid as string | undefined;
    if (!uid) {
      throw new HttpsError('invalid-argument', 'uid required');
    }

    const target = await admin.auth().getUser(uid);
    const existingClaims = (target.customClaims ?? {}) as Record<string, unknown>;
    await admin
      .auth()
      .setCustomUserClaims(uid, { ...existingClaims, role: 'dispatcher' });

    // Mirror the role into the Firestore users doc so the admin panel
    // can drop the "Dispatcher yap" button immediately without waiting
    // for a token refresh round-trip.
    await admin.firestore().collection('users').doc(uid).set(
      {
        role: 'dispatcher',
        roleLabel: 'Dispatcher',
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    await admin.firestore().collection('audit_log').add({
      action: 'assign_dispatcher',
      actorUid: request.auth!.uid,
      targetUid: uid,
      at: FieldValue.serverTimestamp(),
    });

    logger.info('Dispatcher role assigned', {
      targetUid: uid,
      actor: request.auth!.uid,
    });
    return { ok: true };
  },
);

/**
 * Dispatcher-only: promote a `registration_requests` entry to a
 * real `certified_phones` record. Atomic write + audit log entry.
 */
export const approveRegistrationRequest = onCall(
  { region: REGION, cors: true },
  async (request) => {
    assertDispatcher(request.auth?.token as { role?: string } | undefined);
    const requestId = request.data?.requestId as string | undefined;
    if (!requestId) {
      throw new HttpsError('invalid-argument', 'requestId required');
    }
    const db = admin.firestore();
    const reqRef = db.collection('registration_requests').doc(requestId);

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(reqRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Request not found');
      }
      const data = snap.data()!;
      if (data.status !== 'pending') {
        throw new HttpsError('failed-precondition', 'Already decided');
      }
      const phone = data.phone as string | undefined;
      if (!phone || !/^\+[1-9]\d{7,14}$/.test(phone)) {
        throw new HttpsError('invalid-argument', 'Request missing valid phone');
      }

      // Upsert certified_phones/{phoneE164} — same shape as the bulk
      // import callable writes.
      const certRef = db.collection('certified_phones').doc(phone);
      const expiresAt = data.expiresAt instanceof Timestamp
        ? data.expiresAt
        : typeof data.expiresAt === 'string'
          ? Timestamp.fromDate(new Date(data.expiresAt))
          : Timestamp.fromDate(
              new Date(Date.now() + 3 * 365 * 24 * 60 * 60 * 1000),
            );

      tx.set(
        certRef,
        {
          fullName: data.fullName ?? '',
          certificateId: data.certificateId ?? null,
          certificateType:
            data.certificateType ?? 'İleri İlkyardım Sertifikası',
          issuer: data.issuer ?? 'Sağlık Bakanlığı Onaylı',
          expiresAt,
          region: data.region ?? { country: 'TR', city: '', district: '' },
          roleLabel: data.roleLabel ?? 'Gönüllü',
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      tx.update(reqRef, {
        status: 'approved',
        reviewedBy: request.auth!.uid,
        reviewedAt: FieldValue.serverTimestamp(),
      });
    });

    await db.collection('audit_log').add({
      action: 'approve_registration',
      actorUid: request.auth!.uid,
      requestId,
      at: FieldValue.serverTimestamp(),
    });

    logger.info('Registration approved', {
      requestId,
      actor: request.auth!.uid,
    });
    return { ok: true };
  },
);

/** Dispatcher-only: reject a pending registration request. */
export const rejectRegistrationRequest = onCall(
  { region: REGION, cors: true },
  async (request) => {
    assertDispatcher(request.auth?.token as { role?: string } | undefined);
    const requestId = request.data?.requestId as string | undefined;
    const reason = (request.data?.reason as string | undefined) ?? '';
    if (!requestId) {
      throw new HttpsError('invalid-argument', 'requestId required');
    }
    const db = admin.firestore();
    const reqRef = db.collection('registration_requests').doc(requestId);
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(reqRef);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Request not found');
      }
      const data = snap.data()!;
      if (data.status !== 'pending') {
        throw new HttpsError('failed-precondition', 'Already decided');
      }
      tx.update(reqRef, {
        status: 'rejected',
        reviewedBy: request.auth!.uid,
        reviewedAt: FieldValue.serverTimestamp(),
        rejectionReason: reason,
      });
    });

    await db.collection('audit_log').add({
      action: 'reject_registration',
      actorUid: request.auth!.uid,
      requestId,
      reason,
      at: FieldValue.serverTimestamp(),
    });

    logger.info('Registration rejected', {
      requestId,
      actor: request.auth!.uid,
    });
    return { ok: true };
  },
);
