import { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  limit,
} from 'firebase/firestore';
import { db } from '../lib/firebase';

interface Volunteer {
  id: string;
  fullName?: string;
  phone?: string;
  active?: boolean;
  region?: { city?: string; district?: string };
  stats?: { interventions?: number; educationPoints?: number };
  roleLabel?: string;
}

export function Volunteers() {
  const [rows, setRows] = useState<Volunteer[]>([]);
  const [filter, setFilter] = useState('');

  useEffect(() => {
    const q = query(
      collection(db, 'users'),
      orderBy('fullName'),
      limit(200),
    );
    return onSnapshot(q, (snap) => {
      setRows(
        snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<Volunteer, 'id'>),
        })),
      );
    });
  }, []);

  const filtered = rows.filter((r) => {
    const q = filter.toLowerCase();
    return (
      !q ||
      r.fullName?.toLowerCase().includes(q) ||
      r.phone?.includes(q) ||
      r.region?.district?.toLowerCase().includes(q)
    );
  });

  return (
    <div className="p-5 h-screen flex flex-col">
      <header className="mb-4">
        <h1 className="text-2xl font-bold">Gönüllüler</h1>
        <p className="text-sm text-onsurface-variant">
          Toplam {rows.length} · Aktif {rows.filter((r) => r.active).length}
        </p>
      </header>
      <input
        placeholder="İsim, telefon veya ilçe…"
        className="input-field max-w-md mb-3"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
      />
      <div className="card flex-1 overflow-auto p-0">
        <table className="w-full text-sm">
          <thead className="bg-surface-low sticky top-0">
            <tr className="text-left text-xs uppercase tracking-wider text-onsurface-variant">
              <th className="p-3">Ad Soyad</th>
              <th className="p-3">Telefon</th>
              <th className="p-3">Bölge</th>
              <th className="p-3">Rol</th>
              <th className="p-3 text-right">Müdahale</th>
              <th className="p-3 text-right">Puan</th>
              <th className="p-3">Durum</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((r) => (
              <tr key={r.id} className="hover:bg-surface-low">
                <td className="p-3 font-semibold">{r.fullName ?? '—'}</td>
                <td className="p-3 font-mono text-xs">{r.phone ?? '—'}</td>
                <td className="p-3">
                  {r.region?.city ?? ''}
                  {r.region?.district ? ' / ' + r.region.district : ''}
                </td>
                <td className="p-3">{r.roleLabel ?? 'Gönüllü'}</td>
                <td className="p-3 text-right">
                  {r.stats?.interventions ?? 0}
                </td>
                <td className="p-3 text-right">
                  {r.stats?.educationPoints ?? 0}
                </td>
                <td className="p-3">
                  {r.active ? (
                    <span className="text-tertiary font-semibold">Aktif</span>
                  ) : (
                    <span className="text-onsurface-variant">Pasif</span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
