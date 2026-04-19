import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

const REGION = 'europe-west3';

function isValidE164(phone: string): boolean {
  return /^\+[1-9]\d{7,14}$/.test(phone);
}

/**
 * Caller provides a phone number in E.164. We check if there is an active
 * certified_phones document. If yes, the client can then start OTP flow.
 * We intentionally do NOT return identifying info — only ok/reason.
 */
export const checkCertifiedPhone = onCall(
  { region: REGION, cors: true },
  async (request) => {
    const phone = (request.data?.phoneE164 as string | undefined)?.trim();
    if (!phone || !isValidE164(phone)) {
      return { ok: false, reason: 'invalid_format' };
    }

    const doc = await admin
      .firestore()
      .collection('certified_phones')
      .doc(phone)
      .get();

    if (!doc.exists) {
      logger.info('checkCertifiedPhone miss', { phone });
      return { ok: false, reason: 'not_found' };
    }

    const expiresAt = doc.get('expiresAt') as admin.firestore.Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() < Date.now()) {
      return { ok: false, reason: 'expired' };
    }

    return { ok: true };
  },
);

/**
 * After Firebase Auth verifyPhoneNumber succeeds, the client calls this
 * to seed users/{uid} and set custom claim `certified: true`.
 */
export const finalizeSignup = onCall(
  { region: REGION, cors: true },
  async (request) => {
    const uid = request.auth?.uid;
    const phone = request.auth?.token?.phone_number as string | undefined;
    if (!uid || !phone) {
      throw new HttpsError('unauthenticated', 'No auth context');
    }

    const certDoc = await admin
      .firestore()
      .collection('certified_phones')
      .doc(phone)
      .get();

    if (!certDoc.exists) {
      throw new HttpsError('permission-denied', 'Not certified');
    }
    const certData = certDoc.data() ?? {};
    const expiresAt = certData.expiresAt as admin.firestore.Timestamp | undefined;
    if (expiresAt && expiresAt.toMillis() < Date.now()) {
      throw new HttpsError('permission-denied', 'Certificate expired');
    }

    await admin.auth().setCustomUserClaims(uid, { certified: true });

    const userRef = admin.firestore().collection('users').doc(uid);
    const snap = await userRef.get();
    if (!snap.exists) {
      await userRef.set({
        phone,
        fullName: certData.fullName ?? '',
        region: certData.region ?? { country: 'TR', city: '', district: '' },
        roleLabel: certData.roleLabel ?? 'Gönüllü',
        stats: { interventions: 0, educationPoints: 0 },
        badges: [],
        fcmTokens: [],
        active: true,
        certificate: {
          type: certData.certificateType ?? 'İleri İlkyardım Sertifikası',
          issuer: certData.issuer ?? 'Sağlık Bakanlığı Onaylı',
          expiresAt: certData.expiresAt ?? null,
          certificateId: certData.certificateId ?? null,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      await userRef.update({
        active: true,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return { ok: true, uid };
  },
);
