import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import { geohashQueryBounds, distanceBetween } from 'geofire-common';

const REGION = 'europe-west3';

type Severity = 'critical' | 'serious' | 'minor';

const WAVE_PLAN: Record<
  Severity,
  Array<{ radiusKm: number; maxRecipients: number; timeoutSec: number }>
> = {
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

interface NotificationPayload {
  emergencyId: string;
  severity: Severity;
  type: string;
  address: string;
  hazards: string[];
  distanceMeters: number;
  lat: number;
  lng: number;
}

async function fetchNearbyVolunteers(
  lat: number,
  lng: number,
  radiusKm: number,
  exclude: Set<string>,
): Promise<Array<{ uid: string; tokens: string[]; distance: number }>> {
  const radiusM = radiusKm * 1000;
  const bounds = geohashQueryBounds([lat, lng], radiusM);

  const db = admin.firestore();
  const snapshots = await Promise.all(
    bounds.map((b) =>
      db
        .collection('users')
        .where('active', '==', true)
        .orderBy('geohash')
        .startAt(b[0])
        .endAt(b[1])
        .get(),
    ),
  );

  const matches: Array<{ uid: string; tokens: string[]; distance: number }> = [];
  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      if (exclude.has(doc.id)) continue;
      const loc = doc.get('lastLocation') as admin.firestore.GeoPoint | undefined;
      if (!loc) continue;
      const dist = distanceBetween([loc.latitude, loc.longitude], [lat, lng]);
      if (dist * 1000 <= radiusM) {
        const tokens = (doc.get('fcmTokens') as string[] | undefined) ?? [];
        matches.push({ uid: doc.id, tokens, distance: dist * 1000 });
      }
    }
  }
  matches.sort((a, b) => a.distance - b.distance);
  return matches;
}

function buildFcmMessage(
  tokens: string[],
  payload: NotificationPayload,
): admin.messaging.MulticastMessage {
  const data: Record<string, string> = {
    emergencyId: payload.emergencyId,
    severity: payload.severity,
    type: payload.type,
    address: payload.address,
    hazards: payload.hazards.join(','),
    distanceMeters: Math.round(payload.distanceMeters).toString(),
    lat: payload.lat.toString(),
    lng: payload.lng.toString(),
  };

  const isCritical = payload.severity === 'critical';

  return {
    tokens,
    data,
    notification: {
      title: isCritical ? 'ACİL ÇAĞRI' : 'Yeni Çağrı',
      body: `${prettyType(payload.type)} · ${payload.address}`,
    },
    android: {
      priority: 'high',
      notification: {
        channelId: isCritical ? 'critical_alert' : 'new_call',
        visibility: 'public',
        defaultSound: true,
        defaultVibrateTimings: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: isCritical
            ? { critical: 1, name: 'default', volume: 1.0 }
            : 'default',
          'interruption-level': isCritical ? 'critical' : 'time-sensitive',
          badge: 1,
        },
      },
    },
  };
}

function prettyType(key: string): string {
  const map: Record<string, string> = {
    heart_attack: 'Kalp Krizi',
    breathing_difficulty: 'Nefes Darlığı',
    choking: 'Boğulma',
    injury: 'Yaralanma',
    traffic_accident: 'Trafik Kazası',
    poisoning: 'Zehirlenme',
    fall: 'Düşme',
    unconsciousness: 'Bilinç Kaybı',
    other: 'Acil Durum',
  };
  return map[key] ?? 'Acil Durum';
}

/**
 * On new emergency creation, trigger wave 0:
 * - Compute bounds, find nearby active volunteers
 * - Send FCM multicast
 * - Track notified uids
 */
export const onEmergencyCreate = onDocumentCreated(
  { region: REGION, document: 'emergencies/{id}' },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const severity = (data.severity as Severity) ?? 'serious';
    const location = data.location as admin.firestore.GeoPoint | undefined;
    if (!location) return;

    const plan = WAVE_PLAN[severity][0];
    const nearby = await fetchNearbyVolunteers(
      location.latitude,
      location.longitude,
      plan.radiusKm,
      new Set(),
    );
    const recipients = nearby.slice(0, plan.maxRecipients);
    const allTokens = recipients.flatMap((r) => r.tokens);
    if (allTokens.length === 0) {
      logger.info('No recipients in wave 0', { id: event.params.id });
      await snap.ref.update({
        waveLevel: 0,
        notifiedUids: [],
        lastWaveAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    const message = buildFcmMessage(allTokens, {
      emergencyId: event.params.id,
      severity,
      type: data.type as string,
      address: (data.address as string) ?? '',
      hazards: (data.hazards as string[]) ?? [],
      distanceMeters: recipients[0]?.distance ?? 0,
      lat: location.latitude,
      lng: location.longitude,
    });

    const res = await admin.messaging().sendEachForMulticast(message);
    logger.info('Wave 0 push', {
      id: event.params.id,
      success: res.successCount,
      failure: res.failureCount,
    });

    await snap.ref.update({
      waveLevel: 0,
      notifiedUids: recipients.map((r) => r.uid),
      lastWaveAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Atomically claims an emergency. First-come-first-served.
 */
export const acceptEmergency = onCall(
  { region: REGION, cors: true },
  async (request) => {
    if (!request.auth?.token?.certified) {
      throw new HttpsError('permission-denied', 'Not certified');
    }
    const emergencyId = request.data?.emergencyId as string | undefined;
    if (!emergencyId) {
      throw new HttpsError('invalid-argument', 'emergencyId required');
    }
    const uid = request.auth.uid;
    const db = admin.firestore();
    const ref = db.collection('emergencies').doc(emergencyId);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Emergency not found');
      }
      const d = snap.data()!;
      if (d.status !== 'open' || d.acceptedBy != null) {
        throw new HttpsError('failed-precondition', 'Already accepted');
      }
      tx.update(ref, {
        status: 'accepted',
        acceptedBy: uid,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { notifiedUids: (d.notifiedUids as string[]) ?? [] };
    });

    // Notify losers
    const losers = result.notifiedUids.filter((id) => id !== uid);
    if (losers.length) {
      const tokens = await collectTokens(losers);
      if (tokens.length) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          notification: {
            title: 'Çağrı başka bir gönüllüye ulaştı',
            body: 'Başka bir gönüllü müdahaleye başladı. Teşekkürler.',
          },
          data: { emergencyId, type: 'lost_race' },
          android: { priority: 'normal' },
        });
      }
    }

    return { ok: true };
  },
);

async function collectTokens(uids: string[]): Promise<string[]> {
  if (!uids.length) return [];
  const db = admin.firestore();
  const snaps = await db
    .collection('users')
    .where(admin.firestore.FieldPath.documentId(), 'in', uids.slice(0, 30))
    .get();
  return snaps.docs.flatMap((d) => (d.get('fcmTokens') as string[]) ?? []);
}

/**
 * Scheduled every minute: escalate open emergencies whose wave timeout expired.
 */
export const escalateEmergency = onSchedule(
  { region: REGION, schedule: 'every 1 minutes' },
  async () => {
    const now = Date.now();
    const db = admin.firestore();
    const open = await db
      .collection('emergencies')
      .where('status', '==', 'open')
      .limit(50)
      .get();

    for (const doc of open.docs) {
      const data = doc.data();
      const severity = (data.severity as Severity) ?? 'serious';
      const waveLevel = (data.waveLevel as number) ?? 0;
      const plan = WAVE_PLAN[severity][waveLevel];
      if (!plan) continue;
      const lastWaveAt = data.lastWaveAt as admin.firestore.Timestamp | undefined;
      if (!lastWaveAt) continue;
      const elapsed = now - lastWaveAt.toMillis();
      if (elapsed < plan.timeoutSec * 1000) continue;

      const next = WAVE_PLAN[severity][waveLevel + 1];
      if (!next) continue;

      const loc = data.location as admin.firestore.GeoPoint;
      const excluded = new Set<string>((data.notifiedUids as string[]) ?? []);
      const nearby = await fetchNearbyVolunteers(
        loc.latitude,
        loc.longitude,
        next.radiusKm,
        excluded,
      );
      const recipients = nearby.slice(0, next.maxRecipients);
      const tokens = recipients.flatMap((r) => r.tokens);
      if (!tokens.length) continue;

      await admin.messaging().sendEachForMulticast(
        buildFcmMessage(tokens, {
          emergencyId: doc.id,
          severity,
          type: data.type as string,
          address: (data.address as string) ?? '',
          hazards: (data.hazards as string[]) ?? [],
          distanceMeters: recipients[0]?.distance ?? 0,
          lat: loc.latitude,
          lng: loc.longitude,
        }),
      );

      await doc.ref.update({
        waveLevel: waveLevel + 1,
        notifiedUids: admin.firestore.FieldValue.arrayUnion(
          ...recipients.map((r) => r.uid),
        ),
        lastWaveAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  },
);
