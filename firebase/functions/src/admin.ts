import * as admin from 'firebase-admin';
import { onCall, HttpsError, onRequest } from 'firebase-functions/v2/https';
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
            expiresAt: admin.firestore.Timestamp.fromDate(
              new Date(row.expiresAt),
            ),
            region: row.region,
            roleLabel: row.roleLabel ?? 'Gönüllü',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
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
 * One-off HTTP endpoint protected by env SUPERADMIN_TOKEN to assign
 * dispatcher role. Use: curl -H "x-superadmin-token: $T" ...
 */
export const assignDispatcherRole = onRequest(
  { region: REGION, secrets: ['SUPERADMIN_TOKEN'] },
  async (req, res) => {
    const token = process.env.SUPERADMIN_TOKEN;
    if (!token || req.get('x-superadmin-token') !== token) {
      res.status(403).send('forbidden');
      return;
    }
    const uid = req.body?.uid as string | undefined;
    if (!uid) {
      res.status(400).send('uid required');
      return;
    }
    await admin.auth().setCustomUserClaims(uid, { role: 'dispatcher' });
    logger.info('dispatcher claim set', { uid });
    res.status(200).send({ ok: true });
  },
);
