import { useState } from 'react';
import { httpsCallable } from 'firebase/functions';
import { functions } from '../lib/firebase';

interface Row {
  phoneE164: string;
  fullName: string;
  certificateId?: string;
  certificateType?: string;
  expiresAt: string;
  region: { country: string; city: string; district: string };
}

export function Certificates() {
  const [csv, setCsv] = useState('');
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const parse = (raw: string): Row[] => {
    const lines = raw.trim().split(/\r?\n/);
    if (lines.length < 2) return [];
    const [header, ...rest] = lines;
    const cols = header.split(',').map((c) => c.trim());
    const idx = (name: string) => cols.indexOf(name);

    return rest
      .filter((l) => l.trim().length > 0)
      .map((line) => {
        const v = line.split(',').map((c) => c.trim());
        return {
          phoneE164: v[idx('phone')] ?? '',
          fullName: v[idx('fullName')] ?? '',
          certificateId: v[idx('certificateId')] ?? undefined,
          certificateType:
            v[idx('certificateType')] ?? 'İleri İlkyardım Sertifikası',
          expiresAt: v[idx('expiresAt')] ?? '2099-01-01',
          region: {
            country: 'TR',
            city: v[idx('city')] ?? '',
            district: v[idx('district')] ?? '',
          },
        };
      });
  };

  const upload = async () => {
    setError(null);
    setStatus(null);
    const rows = parse(csv);
    if (rows.length === 0) {
      setError('Geçerli CSV satırı bulunamadı');
      return;
    }
    try {
      setStatus(`${rows.length} satır yükleniyor…`);
      const fn = httpsCallable<{ rows: Row[] }, { ok: boolean; written: number }>(
        functions,
        'bulkImportCertifiedPhones',
      );
      const res = await fn({ rows });
      setStatus(`Başarılı. ${res.data.written} kayıt yazıldı.`);
      setCsv('');
    } catch (e) {
      setError('Yükleme başarısız: ' + (e as Error).message);
      setStatus(null);
    }
  };

  return (
    <div className="p-5 h-screen flex flex-col">
      <header className="mb-4">
        <h1 className="text-2xl font-bold">Sertifikalı Telefonlar</h1>
        <p className="text-sm text-onsurface-variant">
          CSV import · sadece bu listedeki numaralar uygulamaya giriş yapabilir.
        </p>
      </header>

      <div className="card mb-4 text-sm">
        <strong>Beklenen sütunlar:</strong>{' '}
        <code className="text-xs">
          phone, fullName, certificateId, certificateType, expiresAt, city, district
        </code>
        <div className="text-xs text-onsurface-variant mt-2">
          Tarih formatı: ISO 8601 (örn. 2027-04-15). Telefon: E.164 (+90…).
        </div>
      </div>

      <textarea
        className="input-field flex-1 font-mono text-xs"
        value={csv}
        onChange={(e) => setCsv(e.target.value)}
        placeholder={`phone,fullName,certificateId,certificateType,expiresAt,city,district\n+905331234567,Ahmet Test,TR-123,İleri İlkyardım Sertifikası,2027-04-15,istanbul,kadikoy`}
      />

      {status && <div className="text-tertiary text-sm mt-2">{status}</div>}
      {error && <div className="text-error text-sm mt-2">{error}</div>}

      <div className="mt-3 flex justify-end">
        <button className="btn-primary" onClick={upload}>
          Yükle
        </button>
      </div>
    </div>
  );
}
