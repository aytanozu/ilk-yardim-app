import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  where,
  limit,
  Timestamp,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import {
  MapContainer,
  Marker,
  Polyline,
  Popup,
  TileLayer,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';
import { db, functions } from '../lib/firebase';
import {
  EMERGENCY_TYPES,
  type EmergencyDoc,
} from '../types/emergency';

interface CandidateScore {
  uid: string;
  certLevel?: string;
  reliability?: number;
  distanceMeters?: number;
  score?: number;
  breakdown?: {
    distance: number;
    competency: number;
    reliability: number;
    total: number;
  };
}

interface VolunteerLocation {
  uid: string;
  lat: number;
  lng: number;
  heading?: number;
  updatedAt?: Timestamp;
}

const CERT_LABEL: Record<string, string> = {
  paramedic: 'Paramedik',
  als: 'İleri Yaşam Desteği',
  bls: 'Temel Yaşam Desteği',
  advanced_first_aid: 'İleri İlkyardım',
  basic_first_aid: 'Temel İlkyardım',
};

const POLYLINE_COLORS = [
  '#b7102a',
  '#006860',
  '#e8a33c',
  '#5b8def',
  '#a855f7',
];

export function Dashboard() {
  const [cases, setCases] = useState<EmergencyDoc[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const [volunteerTrails, setVolunteerTrails] = useState<
    Record<string, VolunteerLocation[]>
  >({});
  const [unresponsive, setUnresponsive] = useState<Record<string, number>>({});
  const nav = useNavigate();

  useEffect(() => {
    const q = query(
      collection(db, 'emergencies'),
      where('status', 'in', ['open', 'accepted']),
      orderBy('createdAt', 'desc'),
      limit(100),
    );
    return onSnapshot(q, (snap) => {
      const rows: EmergencyDoc[] = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<EmergencyDoc, 'id'>),
      }));
      setCases(rows);
    });
  }, []);

  // When a case is expanded, stream volunteer_locations for every uid
  // currently in acceptedBy so the main map can draw their live trails.
  useEffect(() => {
    if (!expandedId) {
      setVolunteerTrails({});
      setUnresponsive({});
      return;
    }
    const ec = cases.find((c) => c.id === expandedId);
    const acceptors = (ec?.acceptedBy as string[] | undefined) ?? [];
    if (acceptors.length === 0) {
      setVolunteerTrails({});
      return;
    }
    const unsubs = acceptors.map((uid) =>
      onSnapshot(doc(db, 'volunteer_locations', uid), (snap) => {
        const d = snap.data() as VolunteerLocation | undefined;
        if (!d) return;
        setVolunteerTrails((prev) => {
          const existing = prev[uid] ?? [];
          const point = {
            uid,
            lat: d.lat,
            lng: d.lng,
            heading: d.heading,
            updatedAt: d.updatedAt,
          };
          const appended = [...existing, point].slice(-50);
          return { ...prev, [uid]: appended };
        });
      }),
    );
    // Subscribe to user docs for unresponsiveSince flag.
    const userSubs = acceptors.map((uid) =>
      onSnapshot(doc(db, 'users', uid), (snap) => {
        const since = snap.get('unresponsiveSince') as Timestamp | undefined;
        setUnresponsive((prev) => ({
          ...prev,
          [uid]: since?.toMillis() ?? 0,
        }));
      }),
    );
    return () => {
      unsubs.forEach((u) => u());
      userSubs.forEach((u) => u());
    };
  }, [expandedId, cases]);

  async function closeCase(id: string, reason: 'cancelled' | 'expired') {
    if (!confirm(
      reason === 'cancelled'
        ? 'Vakayı iptal etmek istediğinizden emin misiniz?'
        : 'Vakayı süresi dolmuş olarak işaretlemek istediğinizden emin misiniz?',
    )) return;
    setBusyId(id);
    try {
      const fn = httpsCallable<
        { emergencyId: string; reason: string },
        { ok: boolean }
      >(functions, 'closeEmergency');
      await fn({ emergencyId: id, reason });
    } catch (e) {
      alert('Vaka kapatılamadı: ' + (e as Error).message);
    } finally {
      setBusyId(null);
    }
  }

  const stats = useMemo(() => {
    const open = cases.filter((c) => c.status === 'open').length;
    const accepted = cases.filter((c) => c.status === 'accepted').length;
    const critical = cases.filter(
      (c) => c.severity === 'critical' && c.status === 'open',
    ).length;
    return { open, accepted, critical };
  }, [cases]);

  return (
    <div className="h-screen flex flex-col">
      <header className="flex items-center justify-between p-5">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">
            Gösterge Paneli
          </h1>
          <p className="text-sm text-onsurface-variant">
            Canlı aktif vakalar ve gönüllü durumu
          </p>
        </div>
        <button className="btn-primary" onClick={() => nav('/new')}>
          + Yeni Çağrı
        </button>
      </header>

      <div className="grid grid-cols-3 gap-3 px-5">
        <StatCard
          label="Açık Çağrı"
          value={stats.open}
          color="severity-critical"
        />
        <StatCard
          label="Devam Eden"
          value={stats.accepted}
          color="severity-serious"
        />
        <StatCard
          label="Kritik"
          value={stats.critical}
          color="primary"
        />
      </div>

      <div className="grid grid-cols-[1fr_360px] gap-3 p-5 flex-1 overflow-hidden">
        <div className="card p-0 overflow-hidden">
          <MapContainer
            center={[41.0082, 28.9784]}
            zoom={11}
            className="h-full w-full"
          >
            <TileLayer
              url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
              attribution='&copy; OpenStreetMap'
            />
            {cases.map((c) => (
              <Marker
                key={c.id}
                position={[c.location.latitude, c.location.longitude]}
                icon={iconForSeverity(c.severity)}
              >
                <Popup>
                  <div className="space-y-1">
                    <div className="font-bold">
                      {EMERGENCY_TYPES[c.type] ?? c.type}
                    </div>
                    <div className="text-xs opacity-75">{c.address}</div>
                    <div className="text-xs">
                      Durum: {c.status === 'accepted' ? 'Müdahalede' : 'Açık'}
                    </div>
                  </div>
                </Popup>
              </Marker>
            ))}
            {Object.entries(volunteerTrails).map(([uid, pts], idx) => {
              if (pts.length < 2) return null;
              const positions = pts.map(
                (p) => [p.lat, p.lng] as [number, number],
              );
              const color = POLYLINE_COLORS[idx % POLYLINE_COLORS.length];
              const head = pts[pts.length - 1];
              return (
                <div key={uid}>
                  <Polyline
                    positions={positions}
                    pathOptions={{ color, weight: 4, opacity: 0.85 }}
                  />
                  <Marker
                    position={[head.lat, head.lng]}
                    icon={L.divIcon({
                      className: '',
                      html: `<div style="background:${color};width:16px;height:16px;border-radius:999px;border:2px solid #fff;box-shadow:0 0 0 2px ${color}50"></div>`,
                      iconSize: [16, 16],
                      iconAnchor: [8, 8],
                    })}
                  />
                </div>
              );
            })}
            <AutoCenter cases={cases} />
          </MapContainer>
        </div>

        <aside className="card p-3 overflow-auto">
          <h2 className="text-sm font-bold tracking-wider text-onsurface-variant uppercase px-2 mb-2">
            Aktif Çağrılar · {cases.length}
          </h2>
          {cases.length === 0 && (
            <div className="text-sm text-onsurface-variant p-3">
              Henüz açık vaka yok.
            </div>
          )}
          <ul className="space-y-2">
            {cases.map((c) => {
              const responders = Array.isArray(c.acceptedBy)
                ? c.acceptedBy.length
                : 0;
              const isExpanded = expandedId === c.id;
              const candidates = ((c as { candidateScores?: CandidateScore[] })
                .candidateScores ?? []) as CandidateScore[];
              return (
                <li
                  key={c.id}
                  className={`bg-surface-low rounded-xl p-3 ${
                    isExpanded ? 'ring-2 ring-primary/40' : 'hover:bg-surface-high'
                  } cursor-pointer`}
                  onClick={() =>
                    c.id && setExpandedId(isExpanded ? null : c.id)
                  }
                >
                  <div className="flex items-center justify-between mb-1">
                    <span
                      className={`text-xs font-bold uppercase tracking-wider ${sevClass(
                        c.severity,
                      )}`}
                    >
                      {sevLabel(c.severity)}
                    </span>
                    <span className="text-xs text-onsurface-variant">
                      {c.status === 'accepted'
                        ? `${responders} gönüllü yolda`
                        : 'Açık'}
                    </span>
                  </div>
                  <div className="font-semibold text-sm">
                    {EMERGENCY_TYPES[c.type] ?? c.type}
                  </div>
                  <div className="text-xs text-onsurface-variant truncate mb-2">
                    {c.address}
                  </div>
                  {isExpanded && (
                    <div className="mt-3 border-t border-onsurface-variant/10 pt-3 space-y-2">
                      <div className="text-[11px] font-bold uppercase tracking-wider text-onsurface-variant">
                        Aday sıralaması
                      </div>
                      {candidates.length === 0 && (
                        <div className="text-xs text-onsurface-variant italic">
                          Henüz aday puanları yok.
                        </div>
                      )}
                      {candidates.slice(0, 5).map((cand, idx) => {
                        const accepted = (c.acceptedBy as string[] | undefined)?.includes(
                          cand.uid,
                        );
                        const unrespMs = unresponsive[cand.uid] ?? 0;
                        const unrespMin = unrespMs
                          ? Math.floor((Date.now() - unrespMs) / 60000)
                          : 0;
                        return (
                          <div
                            key={cand.uid}
                            className="bg-surface-lowest rounded-lg p-2 text-xs"
                            onClick={(e) => e.stopPropagation()}
                          >
                            <div className="flex items-center gap-2">
                              <span
                                className="w-3 h-3 rounded-full"
                                style={{
                                  background:
                                    POLYLINE_COLORS[
                                      idx % POLYLINE_COLORS.length
                                    ],
                                  opacity: accepted ? 1 : 0.25,
                                }}
                              />
                              <span className="font-mono truncate max-w-[110px]">
                                {cand.uid.slice(0, 8)}
                              </span>
                              <span className="font-semibold ml-auto">
                                {cand.score ?? '—'}
                              </span>
                            </div>
                            <div className="mt-1 text-onsurface-variant">
                              {CERT_LABEL[cand.certLevel ?? ''] ?? '—'} ·{' '}
                              {cand.distanceMeters != null
                                ? `${Math.round(cand.distanceMeters)} m`
                                : '—'}{' '}
                              · güv. {cand.reliability ?? '—'}
                            </div>
                            {cand.breakdown && (
                              <div className="text-onsurface-variant opacity-80">
                                D {Math.round(cand.breakdown.distance)} + C{' '}
                                {Math.round(cand.breakdown.competency)} + R{' '}
                                {Math.round(cand.breakdown.reliability)}
                              </div>
                            )}
                            {accepted && unrespMin >= 1 && (
                              <div className="mt-1 inline-block px-2 py-0.5 rounded-full bg-severity-serious/20 text-severity-serious font-semibold">
                                ⚠ {unrespMin} dk sessiz
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                  <div
                    className="flex gap-2 mt-2"
                    onClick={(e) => e.stopPropagation()}
                  >
                    <button
                      disabled={busyId === c.id}
                      onClick={() => c.id && closeCase(c.id, 'cancelled')}
                      className="text-xs px-2 py-1 rounded-md border border-severity-critical/40 text-severity-critical hover:bg-severity-critical/10 disabled:opacity-40"
                    >
                      İptal et
                    </button>
                    <button
                      disabled={busyId === c.id}
                      onClick={() => c.id && closeCase(c.id, 'expired')}
                      className="text-xs px-2 py-1 rounded-md border border-onsurface-variant/40 text-onsurface-variant hover:bg-surface-high disabled:opacity-40"
                    >
                      Süresi doldu
                    </button>
                  </div>
                </li>
              );
            })}
          </ul>
        </aside>
      </div>
    </div>
  );
}

function StatCard({
  label,
  value,
  color,
}: {
  label: string;
  value: number;
  color: string;
}) {
  return (
    <div className="card flex items-center justify-between p-4">
      <div>
        <div className="text-xs font-semibold tracking-wide uppercase text-onsurface-variant">
          {label}
        </div>
        <div className="text-3xl font-bold mt-1">{value}</div>
      </div>
      <div className={`w-1 h-12 rounded-full bg-${color}`} />
    </div>
  );
}

function sevClass(s: string) {
  return s === 'critical'
    ? 'text-severity-critical'
    : s === 'serious'
      ? 'text-severity-serious'
      : 'text-severity-minor';
}
function sevLabel(s: string) {
  return s === 'critical' ? 'Kritik' : s === 'serious' ? 'Ciddi' : 'Destek';
}

function iconForSeverity(s: string) {
  const color =
    s === 'critical' ? '#b7102a' : s === 'serious' ? '#e8a33c' : '#006860';
  return L.divIcon({
    className: '',
    html: `<div style="background:${color};width:28px;height:28px;border-radius:999px;border:3px solid #fff;box-shadow:0 0 0 4px ${color}30"></div>`,
    iconSize: [28, 28],
    iconAnchor: [14, 14],
  });
}

function AutoCenter({ cases }: { cases: EmergencyDoc[] }) {
  const map = useMap();
  useEffect(() => {
    if (cases.length === 0) return;
    const latest = cases[0];
    map.setView(
      [latest.location.latitude, latest.location.longitude],
      13,
      { animate: true },
    );
  }, [cases.length, map, cases]);
  return null;
}
