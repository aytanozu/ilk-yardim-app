import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  where,
  limit,
} from 'firebase/firestore';
import {
  MapContainer,
  Marker,
  Popup,
  TileLayer,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';
import { db } from '../lib/firebase';
import {
  EMERGENCY_TYPES,
  type EmergencyDoc,
} from '../types/emergency';

export function Dashboard() {
  const [cases, setCases] = useState<EmergencyDoc[]>([]);
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
            {cases.map((c) => (
              <li
                key={c.id}
                className="bg-surface-low rounded-xl p-3 cursor-pointer hover:bg-surface-high"
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
                    {c.status === 'accepted' ? 'Müdahalede' : 'Açık'}
                  </span>
                </div>
                <div className="font-semibold text-sm">
                  {EMERGENCY_TYPES[c.type] ?? c.type}
                </div>
                <div className="text-xs text-onsurface-variant truncate">
                  {c.address}
                </div>
              </li>
            ))}
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
