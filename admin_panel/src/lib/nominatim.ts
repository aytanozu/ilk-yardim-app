// OpenStreetMap Nominatim wrapper — free geocoding.
// Keep request rate low; add app email as per Nominatim usage policy.

export interface GeocodeResult {
  lat: number;
  lng: number;
  display: string;
  city?: string;
  district?: string;
}

const BASE = 'https://nominatim.openstreetmap.org';
const EMAIL = 'support@klinik-nabiz.app'; // TODO replace with real
const UA = 'KlinikNabiz/0.1';

export async function reverseGeocode(
  lat: number,
  lng: number,
): Promise<GeocodeResult | null> {
  const res = await fetch(
    `${BASE}/reverse?format=jsonv2&lat=${lat}&lon=${lng}&accept-language=tr&email=${EMAIL}`,
    { headers: { 'User-Agent': UA } },
  );
  if (!res.ok) return null;
  const data = await res.json();
  const addr = data?.address ?? {};
  return {
    lat,
    lng,
    display: data.display_name ?? '',
    city:
      addr.city ?? addr.town ?? addr.state ?? addr.province,
    district:
      addr.suburb ?? addr.county ?? addr.district ?? addr.neighbourhood,
  };
}

export async function searchAddress(query: string): Promise<GeocodeResult[]> {
  if (query.trim().length < 3) return [];
  const res = await fetch(
    `${BASE}/search?format=jsonv2&q=${encodeURIComponent(query)}&countrycodes=tr&limit=6&accept-language=tr&email=${EMAIL}`,
    { headers: { 'User-Agent': UA } },
  );
  if (!res.ok) return [];
  const data = (await res.json()) as Array<Record<string, unknown>>;
  return data.map((d) => ({
    lat: parseFloat(d.lat as string),
    lng: parseFloat(d.lon as string),
    display: d.display_name as string,
  }));
}

export function slugifyRegion(s: string): string {
  return s
    .toLowerCase()
    .replace(/ı/g, 'i')
    .replace(/ş/g, 's')
    .replace(/ç/g, 'c')
    .replace(/ğ/g, 'g')
    .replace(/ü/g, 'u')
    .replace(/ö/g, 'o')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/(^_|_$)/g, '');
}
