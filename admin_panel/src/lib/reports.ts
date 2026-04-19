import {
  collection,
  getDocs,
  orderBy,
  query,
  where,
  limit,
  Timestamp,
  type QueryDocumentSnapshot,
} from 'firebase/firestore';
import { db } from './firebase';
import type { EmergencyDoc, Severity } from '../types/emergency';

export interface EmergencyRecord extends EmergencyDoc {
  id: string;
  createdAtMs: number;
  acceptedAtMs: number | null;
  arrivedAtMs: number | null;
  firstResponderMs: number | null;
}

export async function fetchEmergenciesBetween(
  start: Date,
  end: Date,
): Promise<EmergencyRecord[]> {
  const q = query(
    collection(db, 'emergencies'),
    where('createdAt', '>=', Timestamp.fromDate(start)),
    where('createdAt', '<=', Timestamp.fromDate(end)),
    orderBy('createdAt', 'desc'),
    limit(1000),
  );
  const snap = await getDocs(q);
  return snap.docs.map(fromSnap);
}

function normalizeAcceptedBy(raw: unknown): string[] {
  if (Array.isArray(raw)) return raw as string[];
  if (typeof raw === 'string' && raw) return [raw];
  return [];
}

function fromSnap(d: QueryDocumentSnapshot): EmergencyRecord {
  const data = d.data() as EmergencyDoc & {
    createdAt?: Timestamp;
    acceptedAt?: Timestamp;
    arrivedAt?: Timestamp;
  };
  const createdAtMs = (data.createdAt as Timestamp | undefined)?.toMillis() ?? 0;
  const acceptedAtMs =
    (data.acceptedAt as Timestamp | undefined)?.toMillis() ?? null;
  const arrivedAtMs =
    (data.arrivedAt as Timestamp | undefined)?.toMillis() ?? null;
  const acceptedBy = normalizeAcceptedBy(data.acceptedBy);
  const firstResponderMs = acceptedBy.length > 0 ? acceptedAtMs : null;
  return {
    ...data,
    id: d.id,
    acceptedBy,
    createdAtMs,
    acceptedAtMs,
    arrivedAtMs,
    firstResponderMs,
  };
}

export interface KpiSummary {
  total: number;
  accepted: number;
  arrived: number;
  avgAcceptSec: number | null;
  avgSceneSec: number | null;
  acceptanceRate: number; // 0..1
  closedCount: number;
}

export function computeKpis(records: EmergencyRecord[]): KpiSummary {
  const total = records.length;
  const accepted = records.filter((r) => r.acceptedBy.length > 0).length;
  const arrived = records.filter((r) => r.arrivedAtMs != null).length;

  const acceptTimes = records
    .filter((r) => r.firstResponderMs != null && r.createdAtMs > 0)
    .map((r) => (r.firstResponderMs! - r.createdAtMs) / 1000);
  const avgAcceptSec =
    acceptTimes.length === 0
      ? null
      : acceptTimes.reduce((a, b) => a + b, 0) / acceptTimes.length;

  const sceneTimes = records
    .filter((r) => r.arrivedAtMs != null && r.createdAtMs > 0)
    .map((r) => (r.arrivedAtMs! - r.createdAtMs) / 1000);
  const avgSceneSec =
    sceneTimes.length === 0
      ? null
      : sceneTimes.reduce((a, b) => a + b, 0) / sceneTimes.length;

  const closedCount = records.filter(
    (r) =>
      r.status === 'expired' ||
      r.status === 'cancelled' ||
      r.status === 'resolved',
  ).length;

  return {
    total,
    accepted,
    arrived,
    avgAcceptSec,
    avgSceneSec,
    acceptanceRate: total === 0 ? 0 : accepted / total,
    closedCount,
  };
}

export interface DistrictBucket {
  district: string;
  total: number;
  accepted: number;
  arrived: number;
  acceptanceRate: number;
}

/**
 * Group records by `region.district` for the "Bölgeye göre kabul oranı"
 * bar chart. Districts with no records are omitted. Unnamed districts
 * fall into a single "—" bucket.
 */
export function bucketByDistrict(records: EmergencyRecord[]): DistrictBucket[] {
  const map = new Map<string, DistrictBucket>();
  for (const r of records) {
    const district = r.region?.district || '—';
    const bucket =
      map.get(district) ??
      ({
        district,
        total: 0,
        accepted: 0,
        arrived: 0,
        acceptanceRate: 0,
      } as DistrictBucket);
    bucket.total += 1;
    if (r.acceptedBy.length > 0) bucket.accepted += 1;
    if (r.arrivedAtMs != null) bucket.arrived += 1;
    map.set(district, bucket);
  }
  for (const b of map.values()) {
    b.acceptanceRate = b.total === 0 ? 0 : b.accepted / b.total;
  }
  return Array.from(map.values()).sort((a, b) => b.total - a.total);
}

export interface DailyBucket {
  date: string; // YYYY-MM-DD
  critical: number;
  serious: number;
  minor: number;
  total: number;
}

export function bucketByDay(records: EmergencyRecord[]): DailyBucket[] {
  const map = new Map<string, DailyBucket>();
  for (const r of records) {
    if (r.createdAtMs === 0) continue;
    const date = new Date(r.createdAtMs).toISOString().slice(0, 10);
    const bucket =
      map.get(date) ??
      ({ date, critical: 0, serious: 0, minor: 0, total: 0 } as DailyBucket);
    bucket[r.severity as Severity] = (bucket[r.severity as Severity] ?? 0) + 1;
    bucket.total += 1;
    map.set(date, bucket);
  }
  return Array.from(map.values()).sort((a, b) =>
    a.date < b.date ? -1 : a.date > b.date ? 1 : 0,
  );
}

export interface SeverityResponseAvg {
  severity: Severity;
  avgSec: number;
  count: number;
}

export function responseBySeverity(
  records: EmergencyRecord[],
): SeverityResponseAvg[] {
  const buckets: Record<Severity, number[]> = {
    critical: [],
    serious: [],
    minor: [],
  };
  for (const r of records) {
    if (r.firstResponderMs == null || r.createdAtMs === 0) continue;
    buckets[r.severity as Severity].push(
      (r.firstResponderMs - r.createdAtMs) / 1000,
    );
  }
  return (Object.keys(buckets) as Severity[]).map((s) => ({
    severity: s,
    count: buckets[s].length,
    avgSec:
      buckets[s].length === 0
        ? 0
        : buckets[s].reduce((a, b) => a + b, 0) / buckets[s].length,
  }));
}

export interface Responder {
  uid: string;
  fullName: string;
  region: string;
  interventions: number;
  educationPoints: number;
}

export async function fetchTopResponders(max = 10): Promise<Responder[]> {
  const q = query(
    collection(db, 'users'),
    orderBy('stats.interventions', 'desc'),
    limit(max),
  );
  const snap = await getDocs(q);
  return snap.docs.map((d) => {
    const data = d.data() as {
      fullName?: string;
      region?: { city?: string; district?: string };
      stats?: { interventions?: number; educationPoints?: number };
    };
    return {
      uid: d.id,
      fullName: data.fullName ?? '—',
      region: [data.region?.city, data.region?.district]
        .filter(Boolean)
        .join(' · '),
      interventions: data.stats?.interventions ?? 0,
      educationPoints: data.stats?.educationPoints ?? 0,
    };
  });
}
