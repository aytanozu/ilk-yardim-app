import { useCallback, useEffect, useMemo, useState } from 'react';
import { useForm } from 'react-hook-form';
import { useNavigate } from 'react-router-dom';
import {
  addDoc,
  collection,
  GeoPoint,
  serverTimestamp,
} from 'firebase/firestore';
import {
  MapContainer,
  Marker,
  TileLayer,
  useMapEvents,
  useMap,
} from 'react-leaflet';
import L from 'leaflet';
import { httpsCallable } from 'firebase/functions';
import { auth, db, functions } from '../lib/firebase';
import {
  EMERGENCY_TYPES,
  HAZARDS,
  type EmergencyType,
  type Severity,
} from '../types/emergency';
import { geohashEncode } from '../lib/geohash';
import {
  reverseGeocode,
  searchAddress,
  slugifyRegion,
  type GeocodeResult,
} from '../lib/nominatim';

interface PreviewCandidate {
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

const CERT_LABEL_NE: Record<string, string> = {
  paramedic: 'Paramedik',
  als: 'İleri YD',
  bls: 'Temel YD',
  advanced_first_aid: 'İleri İY',
  basic_first_aid: 'Temel İY',
};

interface FormData {
  type: EmergencyType;
  severity: Severity;
  description: string;
  address: string;
  patientGender: string;
  patientAge: string;
  patientConsciousness: string;
  patientBreathing: string;
  contactPhone: string;
  hazards: string[];
  regionCity: string;
  regionDistrict: string;
}

export function NewEmergency() {
  const nav = useNavigate();
  const [pin, setPin] = useState<{ lat: number; lng: number } | null>(null);
  const [geo, setGeo] = useState<GeocodeResult | null>(null);
  const [suggestions, setSuggestions] = useState<GeocodeResult[]>([]);
  const [searchVal, setSearchVal] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [err, setErr] = useState<string | null>(null);

  const { register, handleSubmit, setValue, watch } = useForm<FormData>({
    defaultValues: {
      type: 'heart_attack',
      severity: 'serious',
      description: '',
      address: '',
      patientGender: '',
      patientAge: '',
      patientConsciousness: '',
      patientBreathing: '',
      contactPhone: '',
      hazards: [],
      regionCity: 'istanbul',
      regionDistrict: 'kadikoy',
    },
  });

  const addr = watch('address');
  const severity = watch('severity');
  const hazards = watch('hazards');
  const type = watch('type');
  const [preview, setPreview] = useState<PreviewCandidate[]>([]);
  const [previewLoading, setPreviewLoading] = useState(false);

  // Debounced live preview: whenever the pin / type / severity changes,
  // ask the backend which volunteers would be notified and what their
  // weighted scores look like. Lets the dispatcher validate cert + reach
  // before committing.
  useEffect(() => {
    if (!pin) {
      setPreview([]);
      return;
    }
    let cancelled = false;
    const t = window.setTimeout(async () => {
      setPreviewLoading(true);
      try {
        const fn = httpsCallable<
          {
            lat: number;
            lng: number;
            type: string;
            severity: string;
            limit: number;
          },
          { ok: boolean; candidates: PreviewCandidate[] }
        >(functions, 'previewDispatchCandidates');
        const res = await fn({
          lat: pin.lat,
          lng: pin.lng,
          type,
          severity,
          limit: 5,
        });
        if (!cancelled) setPreview(res.data.candidates ?? []);
      } catch {
        if (!cancelled) setPreview([]);
      } finally {
        if (!cancelled) setPreviewLoading(false);
      }
    }, 500);
    return () => {
      cancelled = true;
      window.clearTimeout(t);
    };
  }, [pin, type, severity]);

  useEffect(() => {
    if (!pin) return;
    let active = true;
    (async () => {
      const g = await reverseGeocode(pin.lat, pin.lng);
      if (active && g) {
        setGeo(g);
        if (!addr || addr.length === 0) setValue('address', g.display);
        if (g.city) setValue('regionCity', slugifyRegion(g.city));
        if (g.district) setValue('regionDistrict', slugifyRegion(g.district));
      }
    })();
    return () => {
      active = false;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pin]);

  useEffect(() => {
    if (searchVal.trim().length < 3) {
      setSuggestions([]);
      return;
    }
    const t = window.setTimeout(async () => {
      const r = await searchAddress(searchVal);
      setSuggestions(r);
    }, 280);
    return () => window.clearTimeout(t);
  }, [searchVal]);

  const onSubmit = useCallback(
    async (data: FormData) => {
      if (!pin) {
        setErr('Lütfen haritadan konum seçin.');
        return;
      }
      setErr(null);
      setSubmitting(true);
      try {
        // Prefer the explicit form values (dispatcher can override); fall back
        // to Nominatim's parse; final fallback istanbul/kadikoy.
        const city = slugifyRegion(
          (data.regionCity || geo?.city || 'istanbul').trim(),
        );
        const district = slugifyRegion(
          (data.regionDistrict || geo?.district || 'kadikoy').trim(),
        );

        await addDoc(collection(db, 'emergencies'), {
          type: data.type,
          severity: data.severity,
          location: new GeoPoint(pin.lat, pin.lng),
          geohash: geohashEncode(pin.lat, pin.lng, 7),
          address: data.address,
          description: data.description,
          patient: {
            ...(data.patientGender && { gender: data.patientGender }),
            ...(data.patientAge && { age: parseInt(data.patientAge, 10) }),
            ...(data.patientConsciousness && {
              consciousness: data.patientConsciousness,
            }),
            ...(data.patientBreathing && {
              breathing: data.patientBreathing,
            }),
          },
          contactPhone: data.contactPhone || null,
          hazards: data.hazards,
          region: { country: 'TR', city, district },
          status: 'open',
          waveLevel: 0,
          acceptedBy: [],
          notifiedUids: [],
          createdBy: auth.currentUser?.uid,
          createdAt: serverTimestamp(),
          lastWaveAt: serverTimestamp(),
        });
        nav('/');
      } catch (error) {
        setErr('Çağrı oluşturulamadı. Tekrar deneyin.');
      } finally {
        setSubmitting(false);
      }
    },
    [pin, geo, nav],
  );

  return (
    <div className="h-screen grid grid-cols-[1fr_460px]">
      <div className="relative">
        <MapContainer
          center={[41.0082, 28.9784]}
          zoom={12}
          className="h-full w-full"
        >
          <TileLayer
            url="https://tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution="&copy; OpenStreetMap"
          />
          <ClickToPin onPick={(p) => setPin(p)} />
          <PinMarker pin={pin} onDrag={setPin} />
          <MapFlyTo pin={pin} />
        </MapContainer>
        <div className="absolute top-4 left-4 right-4 z-[500]">
          <input
            value={searchVal}
            onChange={(e) => setSearchVal(e.target.value)}
            placeholder="Adres ara (örn. Atatürk Cd., Kadıköy)"
            className="input-field shadow-ambient"
          />
          {suggestions.length > 0 && (
            <ul className="mt-1 bg-surface-lowest rounded-xl shadow-ambient divide-y divide-transparent max-h-72 overflow-auto">
              {suggestions.map((s, i) => (
                <li
                  key={i}
                  onClick={() => {
                    setPin({ lat: s.lat, lng: s.lng });
                    setSearchVal('');
                    setSuggestions([]);
                  }}
                  className="px-4 py-2.5 text-sm cursor-pointer hover:bg-surface-low"
                >
                  {s.display}
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>

      <form
        onSubmit={handleSubmit(onSubmit)}
        className="bg-surface-low overflow-auto"
      >
        <div className="p-5 sticky top-0 bg-surface-low z-10">
          <h1 className="text-xl font-bold">Yeni Çağrı</h1>
          <p className="text-xs text-onsurface-variant">
            Konum zorunlu · Aciliyet dalgayı belirler
          </p>
        </div>

        <div className="p-5 space-y-4">
          <SeverityPicker
            value={severity}
            onChange={(v) => setValue('severity', v)}
          />

          <div>
            <label className="label-field">Vaka Tipi</label>
            <select className="input-field" {...register('type')}>
              {Object.entries(EMERGENCY_TYPES).map(([k, v]) => (
                <option key={k} value={k}>
                  {v}
                </option>
              ))}
            </select>
          </div>

          <div>
            <label className="label-field">Kısa Açıklama</label>
            <textarea
              className="input-field min-h-[80px]"
              maxLength={200}
              placeholder="örn. 65 yaş erkek, göğüs ağrısı, bilinç açık"
              {...register('description', { required: true })}
            />
          </div>

          <div>
            <label className="label-field">Adres</label>
            <input
              className="input-field"
              placeholder="Haritadan pin seçince dolacak"
              {...register('address', { required: true })}
            />
          </div>

          <details className="group" open>
            <summary className="label-field cursor-pointer">
              Hasta & İletişim (opsiyonel)
            </summary>
            <div className="mt-3 space-y-3">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="label-field">Cinsiyet</label>
                  <select
                    className="input-field"
                    {...register('patientGender')}
                  >
                    <option value="">—</option>
                    <option>Kadın</option>
                    <option>Erkek</option>
                    <option>Belirtilmemiş</option>
                  </select>
                </div>
                <div>
                  <label className="label-field">Yaş</label>
                  <input
                    type="number"
                    className="input-field"
                    {...register('patientAge')}
                  />
                </div>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="label-field">Bilinç</label>
                  <select
                    className="input-field"
                    {...register('patientConsciousness')}
                  >
                    <option value="">—</option>
                    <option>Açık</option>
                    <option>Kapalı</option>
                    <option>Bilinmiyor</option>
                  </select>
                </div>
                <div>
                  <label className="label-field">Nefes</label>
                  <select
                    className="input-field"
                    {...register('patientBreathing')}
                  >
                    <option value="">—</option>
                    <option>Var</option>
                    <option>Yok</option>
                    <option>Zor</option>
                    <option>Bilinmiyor</option>
                  </select>
                </div>
              </div>
              <div>
                <label className="label-field">Olay Yeri Telefon</label>
                <input
                  type="tel"
                  className="input-field"
                  placeholder="+90 5XX…"
                  {...register('contactPhone')}
                />
              </div>
            </div>
          </details>

          <div>
            <label className="label-field">Güvenlik Uyarısı</label>
            <div className="flex flex-wrap gap-2">
              {Object.entries(HAZARDS).map(([key, label]) => {
                const active = hazards.includes(key);
                return (
                  <button
                    key={key}
                    type="button"
                    onClick={() => {
                      const next = active
                        ? hazards.filter((h) => h !== key)
                        : [...hazards, key];
                      setValue('hazards', next, { shouldDirty: true });
                    }}
                    className={`px-3 py-1.5 rounded-full text-sm font-medium
                      transition-colors
                      ${active
                        ? 'bg-error text-white'
                        : 'bg-surface-lowest text-onsurface-variant hover:bg-surface-high'}`}
                  >
                    {label}
                  </button>
                );
              })}
            </div>
          </div>

          <div className="bg-surface-lowest rounded-xl p-3 text-xs">
            <div className="font-semibold text-onsurface-variant uppercase tracking-wide">
              Konum
            </div>
            {pin ? (
              <div className="mt-1">
                {pin.lat.toFixed(5)}, {pin.lng.toFixed(5)}
              </div>
            ) : (
              <div className="mt-1 text-onsurface-variant">
                Haritaya tıklayarak pin bırakın
              </div>
            )}
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="label-field">İl (city)</label>
              <input
                className="input-field"
                placeholder="istanbul"
                {...register('regionCity', { required: true })}
              />
            </div>
            <div>
              <label className="label-field">İlçe (district)</label>
              <input
                className="input-field"
                placeholder="kadikoy"
                {...register('regionDistrict', { required: true })}
              />
            </div>
          </div>
          <div className="text-xs text-onsurface-variant -mt-2">
            Küçük harf, boşluksuz, Türkçesiz (ı→i, ş→s). Mobil uygulama bu
            alanlara göre gönüllüleri filtreler.
          </div>

          {pin && (
            <div className="bg-surface-lowest rounded-xl p-3 text-xs">
              <div className="flex items-center justify-between">
                <div className="font-semibold text-onsurface-variant uppercase tracking-wide">
                  Hedef Gönüllüler
                </div>
                {previewLoading && (
                  <div className="text-[10px] text-onsurface-variant">
                    Hesaplanıyor…
                  </div>
                )}
              </div>
              {preview.length === 0 && !previewLoading && (
                <div className="mt-2 text-onsurface-variant">
                  Bu konumda uygun gönüllü bulunamadı.
                </div>
              )}
              <div className="mt-2 space-y-1.5">
                {preview.map((p, idx) => (
                  <div
                    key={p.uid}
                    className="flex items-center gap-2 bg-surface-low rounded-md px-2 py-1.5"
                  >
                    <div className="text-xs font-bold text-primary w-4">
                      {idx + 1}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-mono text-[10px] truncate">
                        {p.uid.slice(0, 8)}
                      </div>
                      <div className="text-[10px] text-onsurface-variant">
                        {CERT_LABEL_NE[p.certLevel ?? ''] ?? '—'} ·{' '}
                        {p.distanceMeters != null
                          ? `${Math.round(p.distanceMeters)} m`
                          : '—'}{' '}
                        · güv.{p.reliability ?? '—'}
                      </div>
                    </div>
                    {p.breakdown && (
                      <div className="text-right text-[10px] font-mono text-onsurface-variant">
                        D{Math.round(p.breakdown.distance)}+C
                        {Math.round(p.breakdown.competency)}+R
                        {Math.round(p.breakdown.reliability)}
                      </div>
                    )}
                    <div className="text-base font-bold text-primary">
                      {p.score ?? '—'}
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {err && <div className="text-error text-sm">{err}</div>}

          <div className="flex gap-2">
            <button
              type="button"
              className="btn-ghost flex-1 justify-center"
              onClick={() => nav('/')}
            >
              İptal (Esc)
            </button>
            <button
              type="submit"
              className="btn-primary flex-1"
              disabled={submitting || !pin}
            >
              {submitting ? 'Yayınlanıyor…' : 'Kaydet & Yayınla (Enter)'}
            </button>
          </div>
        </div>
      </form>
    </div>
  );
}

function SeverityPicker({
  value,
  onChange,
}: {
  value: Severity;
  onChange: (s: Severity) => void;
}) {
  const opts: Array<{ v: Severity; label: string; color: string }> = [
    { v: 'critical', label: 'Kritik', color: 'bg-severity-critical' },
    { v: 'serious', label: 'Ciddi', color: 'bg-severity-serious' },
    { v: 'minor', label: 'Destek', color: 'bg-severity-minor' },
  ];
  return (
    <div>
      <label className="label-field">Aciliyet</label>
      <div className="grid grid-cols-3 gap-2">
        {opts.map((o) => (
          <button
            key={o.v}
            type="button"
            onClick={() => onChange(o.v)}
            className={`p-3 rounded-xl font-semibold text-sm
              transition-all flex flex-col items-center gap-1
              ${value === o.v
                ? `${o.color} text-white shadow-ambient`
                : 'bg-surface-lowest text-onsurface-variant hover:bg-surface-high'}`}
          >
            <span>{o.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}

function ClickToPin({
  onPick,
}: {
  onPick: (p: { lat: number; lng: number }) => void;
}) {
  useMapEvents({
    click(e) {
      onPick({ lat: e.latlng.lat, lng: e.latlng.lng });
    },
  });
  return null;
}

function PinMarker({
  pin,
  onDrag,
}: {
  pin: { lat: number; lng: number } | null;
  onDrag: (p: { lat: number; lng: number }) => void;
}) {
  const icon = useMemo(
    () =>
      L.divIcon({
        className: '',
        html: `<div style="background:#b7102a;width:28px;height:28px;border-radius:999px;border:3px solid #fff;box-shadow:0 0 0 4px #b7102a30"></div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14],
      }),
    [],
  );
  if (!pin) return null;
  return (
    <Marker
      position={[pin.lat, pin.lng]}
      icon={icon}
      draggable
      eventHandlers={{
        dragend: (e) => {
          const ll = e.target.getLatLng();
          onDrag({ lat: ll.lat, lng: ll.lng });
        },
      }}
    />
  );
}

function MapFlyTo({
  pin,
}: {
  pin: { lat: number; lng: number } | null;
}) {
  const map = useMap();
  useEffect(() => {
    if (pin) map.setView([pin.lat, pin.lng], Math.max(map.getZoom(), 15));
  }, [pin, map]);
  return null;
}
