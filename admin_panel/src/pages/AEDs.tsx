import { useEffect, useState } from 'react';
import {
  collection,
  doc,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import { db } from '../lib/firebase';
import { useAuth } from '../context/AuthContext';

type Status = 'pending' | 'active' | 'rejected';

interface AedDoc {
  id: string;
  name?: string;
  address?: string;
  notes?: string;
  status: Status;
  reportedBy?: string;
  verifiedBy?: string;
  location?: { latitude: number; longitude: number };
  createdAt?: Timestamp;
}

export function AEDs() {
  const { user } = useAuth();
  const [filter, setFilter] = useState<Status>('pending');
  const [rows, setRows] = useState<AedDoc[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(
      collection(db, 'aeds'),
      where('status', '==', filter),
      orderBy('createdAt', 'desc'),
      limit(200),
    );
    return onSnapshot(
      q,
      (snap) => {
        setRows(
          snap.docs.map((d) => ({
            id: d.id,
            ...(d.data() as Omit<AedDoc, 'id'>),
          })),
        );
      },
      (err) => setError(err.message),
    );
  }, [filter]);

  async function decide(id: string, next: Status) {
    if (!user) return;
    setBusyId(id);
    try {
      await updateDoc(doc(db, 'aeds', id), {
        status: next,
        verifiedBy: user.uid,
        updatedAt: Timestamp.now(),
      });
    } catch (e) {
      alert('Güncellenemedi: ' + (e as Error).message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="p-5 h-screen flex flex-col">
      <header className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">AED Kayıtları</h1>
          <p className="text-sm text-onsurface-variant">
            Gönüllülerin bildirdiği defibrilatörleri onayla, reddet veya gözden
            geçir.
          </p>
        </div>
        <div className="flex gap-2">
          {(['pending', 'active', 'rejected'] as Status[]).map((s) => (
            <button
              key={s}
              onClick={() => setFilter(s)}
              className={`px-3 py-1.5 rounded-md text-sm border ${
                filter === s
                  ? 'bg-primary text-white border-primary'
                  : 'border-onsurface-variant/20 text-onsurface-variant hover:bg-surface-low'
              }`}
            >
              {s === 'pending'
                ? 'Bekleyen'
                : s === 'active'
                  ? 'Aktif'
                  : 'Reddedilen'}
            </button>
          ))}
        </div>
      </header>

      {error && (
        <div className="card p-3 text-severity-critical text-sm mb-3">
          {error}
        </div>
      )}

      <div className="card flex-1 overflow-auto p-0">
        <table className="w-full text-sm">
          <thead className="bg-surface-low sticky top-0">
            <tr className="text-left text-xs uppercase tracking-wider text-onsurface-variant">
              <th className="p-3">Yer</th>
              <th className="p-3">Adres</th>
              <th className="p-3">Konum</th>
              <th className="p-3">Bildiren</th>
              <th className="p-3 text-right">İşlem</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((r) => (
              <tr key={r.id} className="hover:bg-surface-low align-top">
                <td className="p-3 font-semibold">{r.name ?? '—'}</td>
                <td className="p-3 text-onsurface-variant">
                  {r.address ?? '—'}
                  {r.notes ? (
                    <div className="text-xs opacity-75 mt-1">{r.notes}</div>
                  ) : null}
                </td>
                <td className="p-3 font-mono text-xs">
                  {r.location
                    ? `${r.location.latitude.toFixed(5)}, ${r.location.longitude.toFixed(5)}`
                    : '—'}
                </td>
                <td className="p-3 font-mono text-xs truncate max-w-[140px]">
                  {r.reportedBy ?? '—'}
                </td>
                <td className="p-3 text-right whitespace-nowrap">
                  {filter === 'pending' && (
                    <>
                      <button
                        disabled={busyId === r.id}
                        onClick={() => decide(r.id, 'active')}
                        className="text-xs px-2 py-1 rounded-md border border-tertiary/40 text-tertiary hover:bg-tertiary/10 disabled:opacity-40 mr-2"
                      >
                        Onayla
                      </button>
                      <button
                        disabled={busyId === r.id}
                        onClick={() => decide(r.id, 'rejected')}
                        className="text-xs px-2 py-1 rounded-md border border-severity-critical/40 text-severity-critical hover:bg-severity-critical/10 disabled:opacity-40"
                      >
                        Reddet
                      </button>
                    </>
                  )}
                  {filter === 'active' && (
                    <button
                      disabled={busyId === r.id}
                      onClick={() => decide(r.id, 'rejected')}
                      className="text-xs px-2 py-1 rounded-md border border-severity-critical/40 text-severity-critical hover:bg-severity-critical/10 disabled:opacity-40"
                    >
                      Kaldır
                    </button>
                  )}
                  {filter === 'rejected' && (
                    <button
                      disabled={busyId === r.id}
                      onClick={() => decide(r.id, 'active')}
                      className="text-xs px-2 py-1 rounded-md border border-tertiary/40 text-tertiary hover:bg-tertiary/10 disabled:opacity-40"
                    >
                      Geri al
                    </button>
                  )}
                </td>
              </tr>
            ))}
            {rows.length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="p-6 text-center text-onsurface-variant"
                >
                  Kayıt yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
