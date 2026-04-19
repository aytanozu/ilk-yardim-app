import * as admin from 'firebase-admin';

/**
 * Cached readers for the `app_config/*` Firestore docs. Functions call
 * these instead of reading the collection on every invocation so we
 * don't pay a Firestore read per dispatch. Cache TTL is 5 minutes,
 * which means a dispatcher's config tweak propagates within that window.
 */

const TTL_MS = 5 * 60 * 1000;

interface Cached<T> {
  value: T;
  expiresAt: number;
}

const cache = new Map<string, Cached<unknown>>();

async function readConfig<T>(
  docId: string,
  fallback: T,
): Promise<T> {
  const now = Date.now();
  const hit = cache.get(docId);
  if (hit && hit.expiresAt > now) return hit.value as T;

  try {
    const snap = await admin
      .firestore()
      .collection('app_config')
      .doc(docId)
      .get();
    if (!snap.exists) {
      cache.set(docId, { value: fallback, expiresAt: now + TTL_MS });
      return fallback;
    }
    const value = snap.data() as T;
    cache.set(docId, { value, expiresAt: now + TTL_MS });
    return value;
  } catch {
    // Transient read failure — return cached (even if stale) or fallback.
    if (hit) return hit.value as T;
    return fallback;
  }
}

// ----- Competency -----

export type CertLevel =
  | 'paramedic'
  | 'als'
  | 'bls'
  | 'advanced_first_aid'
  | 'basic_first_aid';

export interface CompetencyConfig {
  certLevels: Record<CertLevel, number>;
  matrix: Record<string, Record<CertLevel, number>>;
  aliases: Record<string, CertLevel>;
}

const COMPETENCY_FALLBACK: CompetencyConfig = {
  certLevels: {
    paramedic: 100,
    als: 90,
    bls: 75,
    advanced_first_aid: 60,
    basic_first_aid: 40,
  },
  matrix: {
    // Fallback: every cert gets its baseline score regardless of incident
    // type. Proper matrix lives in Firestore; this is just a safety net.
    heart_attack: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 60,
      basic_first_aid: 30,
    },
    breathing_difficulty: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 65,
      basic_first_aid: 40,
    },
    choking: {
      paramedic: 95,
      als: 90,
      bls: 85,
      advanced_first_aid: 80,
      basic_first_aid: 70,
    },
    injury: {
      paramedic: 95,
      als: 90,
      bls: 80,
      advanced_first_aid: 80,
      basic_first_aid: 65,
    },
    traffic_accident: {
      paramedic: 100,
      als: 90,
      bls: 80,
      advanced_first_aid: 70,
      basic_first_aid: 50,
    },
    poisoning: {
      paramedic: 100,
      als: 95,
      bls: 75,
      advanced_first_aid: 60,
      basic_first_aid: 40,
    },
    fall: {
      paramedic: 90,
      als: 85,
      bls: 75,
      advanced_first_aid: 70,
      basic_first_aid: 55,
    },
    unconsciousness: {
      paramedic: 100,
      als: 95,
      bls: 85,
      advanced_first_aid: 60,
      basic_first_aid: 30,
    },
    other: {
      paramedic: 80,
      als: 75,
      bls: 70,
      advanced_first_aid: 60,
      basic_first_aid: 50,
    },
  },
  aliases: {
    'İleri İlkyardım Sertifikası': 'advanced_first_aid',
    'Temel İlkyardım Sertifikası': 'basic_first_aid',
    'İleri Yaşam Desteği': 'als',
    'Temel Yaşam Desteği': 'bls',
    Paramedik: 'paramedic',
  },
};

export function loadCompetency(): Promise<CompetencyConfig> {
  return readConfig('competency', COMPETENCY_FALLBACK);
}

/** Resolve a free-text cert type string to a normalized CertLevel. */
export function normalizeCertLevel(
  certType: string | undefined,
  cfg: CompetencyConfig,
): CertLevel {
  if (!certType) return 'basic_first_aid';
  const direct = (certType as string).toLowerCase() as CertLevel;
  if (cfg.certLevels[direct] !== undefined) return direct;
  const aliased = cfg.aliases[certType];
  if (aliased) return aliased;
  return 'basic_first_aid';
}

// ----- Wave plan -----

export type Severity = 'critical' | 'serious' | 'minor';

export interface WavePlanStep {
  radiusKm: number;
  maxRecipients: number;
  timeoutSec: number;
}

export type WavePlan = Record<Severity, WavePlanStep[]>;

const WAVE_PLAN_FALLBACK: WavePlan = {
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

export function loadWavePlan(): Promise<WavePlan> {
  return readConfig('wave_plan', WAVE_PLAN_FALLBACK);
}
