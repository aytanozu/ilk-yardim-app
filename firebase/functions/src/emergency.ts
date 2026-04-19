import * as admin from 'firebase-admin';
import {
  FieldPath,
  FieldValue,
  GeoPoint,
  Timestamp,
} from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { logger } from 'firebase-functions';
import { geohashQueryBounds, distanceBetween } from 'geofire-common';
import { assertWithinRateLimit } from './rate_limit';
import {
  CertLevel,
  CompetencyConfig,
  loadCompetency,
  loadWavePlan,
  normalizeCertLevel,
  Severity,
} from './config_loader';

const REGION = 'europe-west3';

// Hard expiry per severity. OHCA survival drops ~10%/min, so critical
// cases are aggressively timed out; minor supports long-tail scenarios
// like non-urgent assists where a volunteer may not respond for hours.
const EMERGENCY_TTL_MS: Record<Severity, number> = {
  critical: 15 * 60 * 1000,
  serious: 60 * 60 * 1000,
  minor: 4 * 60 * 60 * 1000,
};

// How long wave-0 recipients have to accept before the escalator
// advances. Drives the mobile countdown ring.
const ACCEPT_DEADLINE_SEC = 30;

// Weighted dispatch scoring: 50% distance, 30% competency, 20% reliability.
const W_DISTANCE = 0.5;
const W_COMPETENCY = 0.3;
const W_RELIABILITY = 0.2;

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

export interface ScoreBreakdown {
  distance: number; // 0..100
  competency: number; // 0..100
  reliability: number; // 0..100
  total: number; // weighted sum
}

interface Volunteer {
  uid: string;
  tokens: string[];
  distance: number;
  criticalOnly: boolean;
  certLevel: CertLevel;
  reliability: number;
  score: ScoreBreakdown;
}

/** Bucket raw distance (meters) into a 0..100 score. */
export function distanceBucket(meters: number): number {
  if (meters < 1000) return 100;
  if (meters < 2000) return 80;
  if (meters < 3000) return 60;
  if (meters < 5000) return 40;
  return 20;
}

/**
 * Compute the weighted dispatch score for a volunteer against a specific
 * incident type. Higher is better. Exposed so the operator
 * `previewDispatchCandidates` callable and `onEmergencyCreate` share the
 * same math.
 */
export function scoreVolunteer(
  certLevel: CertLevel,
  reliability: number,
  distanceMeters: number,
  incidentType: string,
  cfg: CompetencyConfig,
): ScoreBreakdown {
  const distance = distanceBucket(distanceMeters);
  const competency = cfg.matrix[incidentType]?.[certLevel] ?? 50;
  const reliab = Math.max(0, Math.min(100, reliability));
  const total =
    W_DISTANCE * distance + W_COMPETENCY * competency + W_RELIABILITY * reliab;
  return { distance, competency, reliability: reliab, total };
}

/**
 * Finds nearby volunteers within radius who are both `active` and `available`.
 * Missing `available` defaults to true via in-memory filter so legacy docs
 * still match. `criticalOnly` notification pref is surfaced and applied by
 * caller based on current severity. Returned list is sorted by the weighted
 * dispatch score (descending), so the first N recipients are the best-fit
 * rather than merely the closest.
 */
async function fetchNearbyVolunteers(
  lat: number,
  lng: number,
  radiusKm: number,
  exclude: Set<string>,
  incidentType: string,
): Promise<Volunteer[]> {
  const radiusM = radiusKm * 1000;
  const bounds = geohashQueryBounds([lat, lng], radiusM);
  const competencyCfg = await loadCompetency();

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

  const matches: Volunteer[] = [];
  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      if (exclude.has(doc.id)) continue;
      // Default-true: treat missing `available` as available.
      if (doc.get('available') === false) continue;
      const loc = doc.get('lastLocation') as GeoPoint | undefined;
      if (!loc) continue;
      const dist = distanceBetween([loc.latitude, loc.longitude], [lat, lng]);
      if (dist * 1000 <= radiusM) {
        const tokens = (doc.get('fcmTokens') as string[] | undefined) ?? [];
        const prefs =
          (doc.get('notificationPrefs') as Record<string, unknown> | undefined) ?? {};
        // Prefer the normalized certLevel written by finalizeSignup /
        // approveRegistrationRequest; fall back to resolving from the
        // free-text certificate.type for legacy users.
        const certLevel: CertLevel =
          (doc.get('certLevel') as CertLevel | undefined) ??
          normalizeCertLevel(
            doc.get('certificate.type') as string | undefined,
            competencyCfg,
          );
        const reliability =
          (doc.get('reliability') as number | undefined) ?? 50;
        const distanceMeters = dist * 1000;
        const score = scoreVolunteer(
          certLevel,
          reliability,
          distanceMeters,
          incidentType,
          competencyCfg,
        );
        matches.push({
          uid: doc.id,
          tokens,
          distance: distanceMeters,
          criticalOnly: prefs.criticalOnly === true,
          certLevel,
          reliability,
          score,
        });
      }
    }
  }
  matches.sort((a, b) => b.score.total - a.score.total);
  return matches;
}

function applyNotificationPrefs(
  volunteers: Volunteer[],
  severity: Severity,
): Volunteer[] {
  if (severity === 'critical') return volunteers;
  return volunteers.filter((v) => !v.criticalOnly);
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
            ? { critical: true, name: 'default', volume: 1.0 }
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
 * - Apply availability + notification pref filters
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
    const location = data.location as GeoPoint | undefined;
    if (!location) return;

    const incidentType = (data.type as string) ?? 'other';
    const wavePlan = await loadWavePlan();
    const plan = wavePlan[severity][0];
    const nearby = await fetchNearbyVolunteers(
      location.latitude,
      location.longitude,
      plan.radiusKm,
      new Set(),
      incidentType,
    );
    const filtered = applyNotificationPrefs(nearby, severity);
    const recipients = filtered.slice(0, plan.maxRecipients);
    const allTokens = recipients.flatMap((r) => r.tokens);

    // Cache a ranked candidate list on the emergency doc so the operator
    // UI can show the weighted score breakdown per responder without
    // recomputing on the client.
    const candidateScores = filtered.slice(0, 20).map((v) => ({
      uid: v.uid,
      certLevel: v.certLevel,
      reliability: v.reliability,
      distanceMeters: Math.round(v.distance),
      breakdown: v.score,
      score: Math.round(v.score.total),
    }));

    if (allTokens.length === 0) {
      logger.info('No recipients in wave 0', { id: event.params.id });
      await snap.ref.update({
        waveLevel: 0,
        notifiedUids: [],
        candidateScores,
        lastWaveAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    const message = buildFcmMessage(allTokens, {
      emergencyId: event.params.id,
      severity,
      type: incidentType,
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

    await _pruneFailedTokens(recipients, allTokens, res);

    // Server-side accept deadline: escalator uses this to auto-advance
    // if nobody accepts in time. Mobile ring counts down against this.
    const deadlineMs = Date.now() + ACCEPT_DEADLINE_SEC * 1000;

    await snap.ref.update({
      waveLevel: 0,
      notifiedUids: recipients.map((r) => r.uid),
      candidateScores,
      acceptDeadline: Timestamp.fromMillis(deadlineMs),
      lastWaveAt: FieldValue.serverTimestamp(),
    });
  },
);

async function _pruneFailedTokens(
  recipients: Volunteer[],
  allTokens: string[],
  res: admin.messaging.BatchResponse,
): Promise<void> {
  const doomedCodes = new Set([
    'messaging/invalid-registration-token',
    'messaging/registration-token-not-registered',
  ]);
  const doomedTokens: string[] = [];
  res.responses.forEach((r, i) => {
    if (!r.success && r.error && doomedCodes.has(r.error.code)) {
      doomedTokens.push(allTokens[i]);
    }
  });
  if (doomedTokens.length === 0) return;

  logger.info('Pruning stale tokens', { count: doomedTokens.length });
  const db = admin.firestore();
  const tokenOwners = new Map<string, string[]>();
  for (const rec of recipients) {
    for (const t of rec.tokens) {
      if (doomedTokens.includes(t)) {
        const arr = tokenOwners.get(rec.uid) ?? [];
        arr.push(t);
        tokenOwners.set(rec.uid, arr);
      }
    }
  }
  const batch = db.batch();
  for (const [uid, tokens] of tokenOwners.entries()) {
    batch.update(db.collection('users').doc(uid), {
      fcmTokens: FieldValue.arrayRemove(...tokens),
    });
  }
  await batch.commit();
}

/**
 * Accepts an emergency. Multi-accept allowed: each uid can join the
 * `acceptedBy` array exactly once. Idempotent — repeat calls by the same
 * uid are no-ops (no double-increment, no duplicate array entries).
 *
 * - First accept flips status `open -> accepted`.
 * - Each unique accept increments the volunteer's `stats.interventions`.
 * - Other previously-notified volunteers get a `case_updated` data push
 *   so their UI can show "N responders en route".
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

    // Soft abuse guard: cap the frequency of accept calls per volunteer
    // to prevent scripted spam. 10/min leaves plenty of headroom for a
    // genuine dispatcher-volunteer interaction.
    await assertWithinRateLimit(`accept:${uid}`, {
      max: 10,
      windowMs: 60_000,
      reasonCode: 'too_many_accepts',
    });

    const db = admin.firestore();
    const ref = db.collection('emergencies').doc(emergencyId);
    const userRef = db.collection('users').doc(uid);

    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Emergency not found');
      }
      const d = snap.data()!;
      const status = d.status as string;
      if (status === 'expired' || status === 'cancelled' || status === 'resolved') {
        throw new HttpsError('failed-precondition', 'Case already closed');
      }
      const rawAccepted = d.acceptedBy;
      const acceptedBy: string[] = Array.isArray(rawAccepted)
        ? (rawAccepted as string[])
        : typeof rawAccepted === 'string' && rawAccepted
          ? [rawAccepted]
          : [];
      const alreadyAccepted = acceptedBy.includes(uid);

      const update: Record<string, unknown> = {
        acceptedBy: FieldValue.arrayUnion(uid),
      };
      // Flip status to 'accepted' only on the very first accept.
      if (acceptedBy.length === 0) {
        update.status = 'accepted';
        update.acceptedAt = FieldValue.serverTimestamp();
      }
      tx.update(ref, update);

      // Server-authoritative intervention counter; idempotent by uid.
      // Also stamp activeEmergencyId so the volunteer's background
      // service can switch into GPS burst mode for this case.
      if (!alreadyAccepted) {
        tx.set(
          userRef,
          {
            stats: { interventions: FieldValue.increment(1) },
            activeEmergencyId: emergencyId,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      return {
        notifiedUids: (d.notifiedUids as string[]) ?? [],
        acceptedBy,
        alreadyAccepted,
        newCount: alreadyAccepted ? acceptedBy.length : acceptedBy.length + 1,
      };
    });

    // Data-only "case_updated" push to previously-notified peers so
    // their UI can reflect "N responders en route".
    const peers = result.notifiedUids.filter(
      (id) => id !== uid && !result.acceptedBy.includes(id),
    );
    if (!result.alreadyAccepted && peers.length) {
      const tokens = await collectTokens(peers);
      if (tokens.length) {
        await admin.messaging().sendEachForMulticast({
          tokens,
          data: {
            emergencyId,
            type: 'case_updated',
            responderCount: result.newCount.toString(),
          },
          android: { priority: 'normal' },
          // iOS silently drops data-only pushes when backgrounded unless
          // content-available is set — this wakes the app long enough for
          // the Firestore listener to process the update.
          apns: {
            headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
            payload: { aps: { 'content-available': 1 } },
          },
        });
      }
    }

    return { ok: true, responderCount: result.newCount };
  },
);

/**
 * Marks the currently-authenticated volunteer as "arrived on scene" for
 * the given emergency. Requires the caller to already be in the
 * `acceptedBy` array. Idempotent — the timestamp is only written once.
 * Exposes a time-to-scene metric distinct from time-to-accept for the
 * admin Reports page.
 */
export const markArrived = onCall(
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

    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) {
        throw new HttpsError('not-found', 'Emergency not found');
      }
      const d = snap.data()!;
      const acceptedBy = Array.isArray(d.acceptedBy)
        ? (d.acceptedBy as string[])
        : typeof d.acceptedBy === 'string' && d.acceptedBy
          ? [d.acceptedBy as string]
          : [];
      if (!acceptedBy.includes(uid)) {
        throw new HttpsError(
          'failed-precondition',
          'Must accept before marking arrived',
        );
      }
      if (d.arrivedAt) return; // idempotent — preserve first-arrival timestamp
      tx.update(ref, {
        arrivedAt: FieldValue.serverTimestamp(),
        arrivedBy: uid,
      });
    });

    return { ok: true };
  },
);

async function collectTokens(uids: string[]): Promise<string[]> {
  if (!uids.length) return [];
  const db = admin.firestore();
  const chunks: string[][] = [];
  for (let i = 0; i < uids.length; i += 30) {
    chunks.push(uids.slice(i, i + 30));
  }
  const all: string[] = [];
  for (const chunk of chunks) {
    const snaps = await db
      .collection('users')
      .where(FieldPath.documentId(), 'in', chunk)
      .get();
    for (const d of snaps.docs) {
      const t = (d.get('fcmTokens') as string[]) ?? [];
      all.push(...t);
    }
  }
  return all;
}

async function broadcastCaseClosed(
  emergencyId: string,
  uids: string[],
  reason: string,
): Promise<void> {
  const unique = Array.from(new Set(uids));
  if (!unique.length) return;
  const tokens = await collectTokens(unique);
  if (!tokens.length) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    data: {
      emergencyId,
      type: 'case_closed',
      reason,
    },
    android: { priority: 'normal' },
    apns: {
      headers: { 'apns-priority': '5', 'apns-push-type': 'background' },
      payload: { aps: { 'content-available': 1 } },
    },
  });
}

/**
 * Scheduled every minute: escalate open emergencies whose wave timeout
 * expired to the next radius band. Also expires any emergency older
 * than EMERGENCY_TTL_MS.
 */
export const escalateEmergency = onSchedule(
  { region: REGION, schedule: 'every 1 minutes' },
  async () => {
    const now = Date.now();
    const db = admin.firestore();
    const wavePlan = await loadWavePlan();
    const activeStatuses = ['open', 'accepted'];
    const snapshots = await Promise.all(
      activeStatuses.map((s) =>
        db.collection('emergencies').where('status', '==', s).limit(100).get(),
      ),
    );
    const docs = snapshots.flatMap((s) => s.docs);

    for (const doc of docs) {
      const data = doc.data();
      const createdAt = data.createdAt as Timestamp | undefined;
      const docSeverity = (data.severity as Severity) ?? 'serious';
      const ttlMs = EMERGENCY_TTL_MS[docSeverity];

      // Severity-tiered hard TTL — close regardless of wave state.
      if (createdAt && now - createdAt.toMillis() > ttlMs) {
        await doc.ref.update({
          status: 'expired',
          closedAt: FieldValue.serverTimestamp(),
          closeReason: 'timeout',
        });
        const acceptedBy = (data.acceptedBy as string[]) ?? [];
        // Drop every acceptor out of GPS burst mode.
        if (acceptedBy.length) {
          const batch = db.batch();
          for (const uid of acceptedBy) {
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
        const peers = [
          ...((data.notifiedUids as string[]) ?? []),
          ...acceptedBy,
        ];
        await broadcastCaseClosed(doc.id, peers, 'timeout');
        logger.info('Emergency expired by TTL', {
          id: doc.id,
          severity: docSeverity,
          ttlMinutes: Math.round(ttlMs / 60000),
        });
        continue;
      }

      // Unresponsive-volunteer detection: for accepted cases still in
      // progress, flag any acceptor whose volunteer_locations heartbeat
      // is >60s stale. Operator UI renders an orange "sessiz" chip.
      const acceptedByUids = Array.isArray(data.acceptedBy)
        ? (data.acceptedBy as string[])
        : [];
      if (data.status === 'accepted' && acceptedByUids.length > 0) {
        const staleThreshold = now - 60_000;
        const locSnaps = await Promise.all(
          acceptedByUids.map((uid) =>
            db.collection('volunteer_locations').doc(uid).get(),
          ),
        );
        const userBatch = db.batch();
        let userWrites = 0;
        for (let i = 0; i < locSnaps.length; i++) {
          const uid = acceptedByUids[i];
          const locSnap = locSnaps[i];
          const loc = locSnap.data();
          const lastBeat =
            (loc?.updatedAt as Timestamp | undefined)?.toMillis() ?? 0;
          const userRef = db.collection('users').doc(uid);
          if (lastBeat > 0 && lastBeat < staleThreshold) {
            userBatch.set(
              userRef,
              { unresponsiveSince: Timestamp.fromMillis(lastBeat) },
              { merge: true },
            );
            userWrites++;
          } else if (lastBeat >= staleThreshold) {
            // Fresh heartbeat — clear any prior flag.
            userBatch.set(
              userRef,
              { unresponsiveSince: FieldValue.delete() },
              { merge: true },
            );
            userWrites++;
          }
        }
        if (userWrites > 0) await userBatch.commit();
      }

      // Only escalate if still 'open' (accepted cases don't need more responders
      // via escalation; resolution is driven by dispatcher or timeout).
      if (data.status !== 'open') continue;

      const severity = (data.severity as Severity) ?? 'serious';
      const incidentType = (data.type as string) ?? 'other';
      const waveLevel = (data.waveLevel as number) ?? 0;
      const plan = wavePlan[severity][waveLevel];
      if (!plan) continue;
      const lastWaveAt = data.lastWaveAt as Timestamp | undefined;
      if (!lastWaveAt) continue;
      // Also treat an expired acceptDeadline as "fire the next wave now",
      // so the 30s countdown ring on wave-0 auto-escalates without
      // waiting for the old coarse wave timeout.
      const acceptDeadline = data.acceptDeadline as Timestamp | undefined;
      const deadlinePassed =
        acceptDeadline != null && now > acceptDeadline.toMillis();
      const elapsed = now - lastWaveAt.toMillis();
      if (elapsed < plan.timeoutSec * 1000 && !deadlinePassed) continue;

      const next = wavePlan[severity][waveLevel + 1];
      if (!next) continue;

      const loc = data.location as GeoPoint;
      const excluded = new Set<string>((data.notifiedUids as string[]) ?? []);
      const nearby = await fetchNearbyVolunteers(
        loc.latitude,
        loc.longitude,
        next.radiusKm,
        excluded,
        incidentType,
      );
      const filtered = applyNotificationPrefs(nearby, severity);
      const recipients = filtered.slice(0, next.maxRecipients);
      const tokens = recipients.flatMap((r) => r.tokens);
      if (!tokens.length) continue;

      await admin.messaging().sendEachForMulticast(
        buildFcmMessage(tokens, {
          emergencyId: doc.id,
          severity,
          type: incidentType,
          address: (data.address as string) ?? '',
          hazards: (data.hazards as string[]) ?? [],
          distanceMeters: recipients[0]?.distance ?? 0,
          lat: loc.latitude,
          lng: loc.longitude,
        }),
      );

      const nextDeadlineMs = now + ACCEPT_DEADLINE_SEC * 1000;
      await doc.ref.update({
        waveLevel: waveLevel + 1,
        notifiedUids: FieldValue.arrayUnion(
          ...recipients.map((r) => r.uid),
        ),
        lastWaveAt: FieldValue.serverTimestamp(),
        acceptDeadline: Timestamp.fromMillis(nextDeadlineMs),
      });
    }
  },
);

/**
 * Dispatcher-only preview for the 3-step new-emergency form: returns the
 * ranked top-N volunteer candidates for a hypothetical incident at
 * (lat, lng, type, severity) WITHOUT writing anything. Dispatcher sees
 * the same candidate list the real dispatch would target before hitting
 * submit.
 */
export const previewDispatchCandidates = onCall(
  { region: REGION, cors: true },
  async (request) => {
    if (request.auth?.token?.role !== 'dispatcher') {
      throw new HttpsError('permission-denied', 'dispatcher only');
    }
    const { lat, lng, type, severity, limit } = (request.data ?? {}) as {
      lat?: number;
      lng?: number;
      type?: string;
      severity?: Severity;
      limit?: number;
    };
    if (typeof lat !== 'number' || typeof lng !== 'number') {
      throw new HttpsError('invalid-argument', 'lat/lng required');
    }
    const incidentType = type ?? 'other';
    const sev: Severity = severity ?? 'serious';

    const wavePlan = await loadWavePlan();
    const plan = wavePlan[sev][0];
    const nearby = await fetchNearbyVolunteers(
      lat,
      lng,
      plan.radiusKm,
      new Set(),
      incidentType,
    );
    const max = Math.max(1, Math.min(limit ?? 10, 20));
    const candidates = nearby.slice(0, max).map((v) => ({
      uid: v.uid,
      certLevel: v.certLevel,
      reliability: v.reliability,
      distanceMeters: Math.round(v.distance),
      breakdown: v.score,
      score: Math.round(v.score.total),
    }));
    return { ok: true, candidates };
  },
);
