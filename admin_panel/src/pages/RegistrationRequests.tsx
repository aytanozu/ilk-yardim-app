import { useEffect, useState } from 'react';
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  Timestamp,
  where,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions } from '../lib/firebase';

type Status = 'pending' | 'approved' | 'rejected';

interface RegRequest {
  id: string;
  phone?: string;
  fullName?: string;
  certificateId?: string;
  certificateType?: string;
  issuer?: string;
  region?: { country?: string; city?: string; district?: string };
  expiresAt?: Timestamp;
  certificateImageUrl?: string;
  status: Status;
  submittedAt?: Timestamp;
  rejectionReason?: string;
}

export function RegistrationRequests() {
  const [filter, setFilter] = useState<Status>('pending');
  const [rows, setRows] = useState<RegRequest[]>([]);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const q = query(
      collection(db, 'registration_requests'),
      where('status', '==', filter),
      orderBy('submittedAt', 'desc'),
      limit(200),
    );
    return onSnapshot(
      q,
      (snap) => {
        setRows(
          snap.docs.map((d) => ({
            id: d.id,
            ...(d.data() as Omit<RegRequest, 'id'>),
          })),
        );
      },
      (err) => setError(err.message),
    );
  }, [filter]);

  async function approve(id: string) {
    if (!confirm('Bu başvuru onaylansın ve sertifikalı listesine eklensin mi?'))
      return;
    setBusyId(id);
    try {
      const fn = httpsCallable<{ requestId: string }, { ok: boolean }>(
        functions,
        'approveRegistrationRequest',
      );
      await fn({ requestId: id });
    } catch (e) {
      alert('Onaylanamadı: ' + (e as Error).message);
    } finally {
      setBusyId(null);
    }
  }

  async function reject(id: string) {
    const reason = prompt('Red nedeni (opsiyonel):') ?? '';
    if (!confirm('Başvuru reddedilsin mi?')) return;
    setBusyId(id);
    try {
      const fn = httpsCallable<
        { requestId: string; reason: string },
        { ok: boolean }
      >(functions, 'rejectRegistrationRequest');
      await fn({ requestId: id, reason });
    } catch (e) {
      alert('Reddedilemedi: ' + (e as Error).message);
    } finally {
      setBusyId(null);
    }
  }

  return (
    <div className="p-5 h-screen flex flex-col">
      <header className="mb-4 flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold">Gönüllü Başvuruları</h1>
          <p className="text-sm text-onsurface-variant">
            Self-servis başvuruları inceleyin, sertifika fotoğrafını doğrulayın
            ve onaylayın.
          </p>
        </div>
        <div className="flex gap-2">
          {(['pending', 'approved', 'rejected'] as Status[]).map((s) => (
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
                : s === 'approved'
                  ? 'Onaylanan'
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

      <div className="flex-1 overflow-auto space-y-3">
        {rows.map((r) => (
          <article key={r.id} className="card p-4">
            <div className="grid grid-cols-[120px_1fr_auto] gap-4">
              <div>
                {r.certificateImageUrl ? (
                  <a
                    href={r.certificateImageUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    <img
                      src={r.certificateImageUrl}
                      alt="Sertifika"
                      className="w-[120px] h-[120px] object-cover rounded-md border border-onsurface-variant/20"
                    />
                  </a>
                ) : (
                  <div className="w-[120px] h-[120px] bg-surface-low rounded-md flex items-center justify-center text-xs text-onsurface-variant">
                    Fotoğraf yok
                  </div>
                )}
              </div>
              <div>
                <div className="text-base font-semibold">
                  {r.fullName ?? '—'}
                </div>
                <div className="text-sm text-onsurface-variant font-mono">
                  {r.phone ?? '—'}
                </div>
                <div className="grid grid-cols-2 gap-2 mt-2 text-sm">
                  <div>
                    <span className="text-onsurface-variant">Sertifika No:</span>{' '}
                    {r.certificateId ?? '—'}
                  </div>
                  <div>
                    <span className="text-onsurface-variant">Veren:</span>{' '}
                    {r.issuer ?? '—'}
                  </div>
                  <div>
                    <span className="text-onsurface-variant">Bölge:</span>{' '}
                    {[r.region?.city, r.region?.district]
                      .filter(Boolean)
                      .join(' / ') || '—'}
                  </div>
                  <div>
                    <span className="text-onsurface-variant">Son Tarih:</span>{' '}
                    {r.expiresAt
                      ? r.expiresAt.toDate().toLocaleDateString('tr-TR')
                      : '—'}
                  </div>
                </div>
                {r.rejectionReason && (
                  <div className="mt-2 text-xs text-severity-critical">
                    Red nedeni: {r.rejectionReason}
                  </div>
                )}
              </div>
              {filter === 'pending' && (
                <div className="flex flex-col gap-2">
                  <button
                    disabled={busyId === r.id}
                    onClick={() => approve(r.id)}
                    className="text-xs px-3 py-2 rounded-md bg-tertiary text-white hover:opacity-90 disabled:opacity-40"
                  >
                    Onayla
                  </button>
                  <button
                    disabled={busyId === r.id}
                    onClick={() => reject(r.id)}
                    className="text-xs px-3 py-2 rounded-md border border-severity-critical/40 text-severity-critical hover:bg-severity-critical/10 disabled:opacity-40"
                  >
                    Reddet
                  </button>
                </div>
              )}
            </div>
          </article>
        ))}
        {rows.length === 0 && (
          <div className="card p-6 text-center text-sm text-onsurface-variant">
            Kayıt yok.
          </div>
        )}
      </div>
    </div>
  );
}
