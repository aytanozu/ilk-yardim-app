import { useEffect, useMemo, useState } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  bucketByDay,
  bucketByDistrict,
  computeKpis,
  fetchEmergenciesBetween,
  fetchTopResponders,
  responseBySeverity,
  type EmergencyRecord,
  type Responder,
} from '../lib/reports';

type Range = '7d' | '30d' | '90d';

const RANGE_LABELS: Record<Range, string> = {
  '7d': 'Son 7 gün',
  '30d': 'Son 30 gün',
  '90d': 'Son 90 gün',
};

export function Reports() {
  const [range, setRange] = useState<Range>('7d');
  const [records, setRecords] = useState<EmergencyRecord[]>([]);
  const [responders, setResponders] = useState<Responder[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      try {
        const end = new Date();
        const start = new Date(end);
        const days = range === '7d' ? 7 : range === '30d' ? 30 : 90;
        start.setDate(start.getDate() - days);
        const [recs, tops] = await Promise.all([
          fetchEmergenciesBetween(start, end),
          fetchTopResponders(10),
        ]);
        if (cancelled) return;
        setRecords(recs);
        setResponders(tops);
      } catch (e) {
        if (!cancelled) setError((e as Error).message);
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [range]);

  const kpis = useMemo(() => computeKpis(records), [records]);
  const daily = useMemo(() => bucketByDay(records), [records]);
  const sevResp = useMemo(() => responseBySeverity(records), [records]);
  const byDistrict = useMemo(() => bucketByDistrict(records), [records]);

  return (
    <div className="p-5 space-y-5">
      <header className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold tracking-tight">Raporlar</h1>
          <p className="text-sm text-onsurface-variant">
            Vaka istatistikleri ve gönüllü performansı
          </p>
        </div>
        <div className="flex gap-2">
          {(Object.keys(RANGE_LABELS) as Range[]).map((r) => (
            <button
              key={r}
              onClick={() => setRange(r)}
              className={`px-3 py-1.5 rounded-md text-sm border ${
                range === r
                  ? 'bg-primary text-white border-primary'
                  : 'border-onsurface-variant/20 text-onsurface-variant hover:bg-surface-low'
              }`}
            >
              {RANGE_LABELS[r]}
            </button>
          ))}
        </div>
      </header>

      {error && (
        <div className="card p-4 text-severity-critical">
          Veriler yüklenemedi: {error}
        </div>
      )}
      {loading && (
        <div className="card p-4 text-sm text-onsurface-variant">
          Yükleniyor…
        </div>
      )}

      <section className="grid grid-cols-5 gap-3">
        <KpiCard label="Toplam Çağrı" value={kpis.total.toString()} />
        <KpiCard
          label="Ort. Kabul Süresi"
          value={
            kpis.avgAcceptSec == null ? '—' : formatSec(kpis.avgAcceptSec)
          }
          hint="oluşturma → ilk kabul"
        />
        <KpiCard
          label="Ort. Varış Süresi"
          value={kpis.avgSceneSec == null ? '—' : formatSec(kpis.avgSceneSec)}
          hint="oluşturma → olay yeri"
        />
        <KpiCard
          label="Kabul Oranı"
          value={`${Math.round(kpis.acceptanceRate * 100)}%`}
          hint={`${kpis.arrived}/${kpis.accepted} varış bildirdi`}
        />
        <KpiCard
          label="Kapatılan"
          value={kpis.closedCount.toString()}
          hint="iptal · süresi dolan · çözülen"
        />
      </section>

      <section className="card p-4">
        <h2 className="text-sm font-bold tracking-wider text-onsurface-variant uppercase mb-3">
          Günlük Vakalar (şiddete göre)
        </h2>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <LineChart data={daily}>
              <CartesianGrid strokeDasharray="3 3" opacity={0.25} />
              <XAxis dataKey="date" fontSize={11} />
              <YAxis allowDecimals={false} fontSize={11} />
              <Tooltip />
              <Line
                type="monotone"
                dataKey="critical"
                stroke="#b7102a"
                strokeWidth={2}
                name="Kritik"
              />
              <Line
                type="monotone"
                dataKey="serious"
                stroke="#e8a33c"
                strokeWidth={2}
                name="Ciddi"
              />
              <Line
                type="monotone"
                dataKey="minor"
                stroke="#006860"
                strokeWidth={2}
                name="Destek"
              />
            </LineChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="card p-4">
        <h2 className="text-sm font-bold tracking-wider text-onsurface-variant uppercase mb-3">
          Ortalama Yanıt Süresi (şiddete göre, saniye)
        </h2>
        <div className="h-56">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={sevResp.map((s) => ({
                severity:
                  s.severity === 'critical'
                    ? 'Kritik'
                    : s.severity === 'serious'
                      ? 'Ciddi'
                      : 'Destek',
                avgSec: Math.round(s.avgSec),
                count: s.count,
              }))}
            >
              <CartesianGrid strokeDasharray="3 3" opacity={0.25} />
              <XAxis dataKey="severity" fontSize={12} />
              <YAxis fontSize={11} />
              <Tooltip />
              <Bar dataKey="avgSec" fill="#b7102a" name="Saniye" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="card p-4">
        <h2 className="text-sm font-bold tracking-wider text-onsurface-variant uppercase mb-3">
          Bölgeye Göre Kabul Oranı
        </h2>
        <div className="h-64">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart
              data={byDistrict.map((b) => ({
                district: b.district,
                total: b.total,
                accepted: b.accepted,
                arrived: b.arrived,
                acceptanceRate: Math.round(b.acceptanceRate * 100),
              }))}
            >
              <CartesianGrid strokeDasharray="3 3" opacity={0.25} />
              <XAxis dataKey="district" fontSize={11} />
              <YAxis fontSize={11} allowDecimals={false} />
              <Tooltip />
              <Bar dataKey="total" fill="#5B403F" name="Toplam" />
              <Bar dataKey="accepted" fill="#b7102a" name="Kabul edilen" />
              <Bar dataKey="arrived" fill="#006860" name="Varış bildirildi" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </section>

      <section className="card p-4">
        <h2 className="text-sm font-bold tracking-wider text-onsurface-variant uppercase mb-3">
          En Aktif Gönüllüler
        </h2>
        <table className="w-full text-sm">
          <thead>
            <tr className="text-left text-onsurface-variant">
              <th className="py-2 font-semibold">İsim</th>
              <th className="py-2 font-semibold">Bölge</th>
              <th className="py-2 font-semibold text-right">Müdahale</th>
              <th className="py-2 font-semibold text-right">Puan</th>
            </tr>
          </thead>
          <tbody>
            {responders.map((r) => (
              <tr key={r.uid} className="border-t border-onsurface-variant/10">
                <td className="py-2">{r.fullName}</td>
                <td className="py-2 text-onsurface-variant">{r.region}</td>
                <td className="py-2 text-right font-semibold">
                  {r.interventions}
                </td>
                <td className="py-2 text-right">{r.educationPoints}</td>
              </tr>
            ))}
            {responders.length === 0 && (
              <tr>
                <td
                  colSpan={4}
                  className="py-6 text-center text-onsurface-variant"
                >
                  Henüz kayıt yok.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </section>
    </div>
  );
}

function KpiCard({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string;
}) {
  return (
    <div className="card p-4">
      <div className="text-xs font-semibold tracking-wide uppercase text-onsurface-variant">
        {label}
      </div>
      <div className="text-3xl font-bold mt-1">{value}</div>
      {hint && (
        <div className="text-[11px] text-onsurface-variant mt-1">{hint}</div>
      )}
    </div>
  );
}

function formatSec(sec: number): string {
  if (sec < 60) return `${Math.round(sec)} sn`;
  const m = Math.floor(sec / 60);
  const s = Math.round(sec - m * 60);
  return `${m}dk ${s}sn`;
}
