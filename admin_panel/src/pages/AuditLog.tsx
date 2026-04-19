import { useEffect, useMemo, useState } from 'react';
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
} from 'firebase/firestore';
import { db } from '../lib/firebase';

interface AuditEntry {
  id: string;
  action: string;
  actorUid?: string;
  targetUid?: string;
  emergencyId?: string;
  reason?: string;
  at?: Timestamp;
}

const ACTION_LABELS: Record<string, string> = {
  assign_dispatcher: 'Dispatcher atandı',
  close_emergency: 'Vaka kapatıldı',
};

export function AuditLog() {
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [actionFilter, setActionFilter] = useState<string>('all');

  useEffect(() => {
    const q = query(
      collection(db, 'audit_log'),
      orderBy('at', 'desc'),
      limit(500),
    );
    return onSnapshot(q, (snap) => {
      setEntries(
        snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as Omit<AuditEntry, 'id'>),
        })),
      );
    });
  }, []);

  const actions = useMemo(() => {
    const s = new Set<string>();
    for (const e of entries) if (e.action) s.add(e.action);
    return Array.from(s).sort();
  }, [entries]);

  const filtered = useMemo(() => {
    if (actionFilter === 'all') return entries;
    return entries.filter((e) => e.action === actionFilter);
  }, [entries, actionFilter]);

  return (
    <div className="p-5 h-screen flex flex-col">
      <header className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Denetim Kayıtları</h1>
          <p className="text-sm text-onsurface-variant">
            Son 500 yönetici işlemi (dispatcher atama, vaka kapatma, vb.)
          </p>
        </div>
        <select
          className="input-field"
          value={actionFilter}
          onChange={(e) => setActionFilter(e.target.value)}
        >
          <option value="all">Tüm işlemler</option>
          {actions.map((a) => (
            <option key={a} value={a}>
              {ACTION_LABELS[a] ?? a}
            </option>
          ))}
        </select>
      </header>

      <div className="card flex-1 overflow-auto p-0">
        <table className="w-full text-sm">
          <thead className="bg-surface-low sticky top-0">
            <tr className="text-left text-xs uppercase tracking-wider text-onsurface-variant">
              <th className="p-3">Zaman</th>
              <th className="p-3">İşlem</th>
              <th className="p-3">Yapan (UID)</th>
              <th className="p-3">Hedef</th>
              <th className="p-3">Detay</th>
            </tr>
          </thead>
          <tbody>
            {filtered.map((e) => (
              <tr key={e.id} className="hover:bg-surface-low align-top">
                <td className="p-3 whitespace-nowrap">
                  {formatTime(e.at)}
                </td>
                <td className="p-3">
                  <span className="font-semibold">
                    {ACTION_LABELS[e.action] ?? e.action}
                  </span>
                </td>
                <td className="p-3 font-mono text-xs truncate max-w-[140px]">
                  {e.actorUid ?? '—'}
                </td>
                <td className="p-3 font-mono text-xs truncate max-w-[220px]">
                  {e.targetUid ?? e.emergencyId ?? '—'}
                </td>
                <td className="p-3 text-onsurface-variant">
                  {e.reason ?? ''}
                </td>
              </tr>
            ))}
            {filtered.length === 0 && (
              <tr>
                <td
                  colSpan={5}
                  className="p-6 text-center text-onsurface-variant"
                >
                  Kayıt bulunamadı.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function formatTime(ts?: Timestamp): string {
  if (!ts) return '—';
  const d = ts.toDate();
  return d.toLocaleString('tr-TR', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
}
