import { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  limit,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../lib/firebase';

interface Volunteer {
  id: string;
  fullName?: string;
  phone?: string;
  active?: boolean;
  region?: { city?: string; district?: string };
  stats?: { interventions?: number; educationPoints?: number };
  roleLabel?: string;
  role?: string;
}

export function Volunteers() {
  const [rows, setRows] = useState<Volunteer[]>([]);
  const [filter, setFilter] = useState('');
  const [busyUid, setBusyUid] = useState<string | null>(null);

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

  async function promoteToDispatcher(v: Volunteer) {
    if (
      !confirm(
        `${v.fullName ?? v.id} kullanıcısına dispatcher yetkisi verilsin mi?`,
      )
    )
      return;
    setBusyUid(v.id);
    try {
      const fn = httpsCallable<{ uid: string }, { ok: boolean }>(
        functions,
        'assignDispatcherRole',
      );
      await fn({ uid: v.id });
      alert('Yetki verildi. Kullanıcı bir sonraki oturum açışında aktifleşecek.');
    } catch (e) {
      alert('Yetki verilemedi: ' + (e as Error).message);
    } finally {
      setBusyUid(null);
    }
  }

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
              <th className="p-3 text-right">İşlem</th>
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
                <td className="p-3">
                  {r.role === 'dispatcher' ? (
                    <span className="text-primary font-semibold">
                      Dispatcher
                    </span>
                  ) : (
                    (r.roleLabel ?? 'Gönüllü')
                  )}
                </td>
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
                <td className="p-3 text-right">
                  {r.role !== 'dispatcher' && (
                    <button
                      disabled={busyUid === r.id}
                      onClick={() => promoteToDispatcher(r)}
                      className="text-xs px-2 py-1 rounded-md border border-primary/40 text-primary hover:bg-primary/10 disabled:opacity-40"
                    >
                      Dispatcher yap
                    </button>
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
