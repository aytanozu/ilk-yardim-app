// Small geohash encoder (base32) for regional indexing to match mobile client.
const B = '0123456789bcdefghjkmnpqrstuvwxyz';

export function geohashEncode(lat: number, lng: number, precision = 7): string {
  let latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  let bit = 0;
  let ch = 0;
  let even = true;
  let hash = '';

  while (hash.length < precision) {
    if (even) {
      const mid = (lngMin + lngMax) / 2;
      if (lng >= mid) { ch = (ch << 1) + 1; lngMin = mid; }
      else { ch <<= 1; lngMax = mid; }
    } else {
      const mid = (latMin + latMax) / 2;
      if (lat >= mid) { ch = (ch << 1) + 1; latMin = mid; }
      else { ch <<= 1; latMax = mid; }
    }
    even = !even;
    if (++bit === 5) {
      hash += B[ch];
      bit = 0;
      ch = 0;
    }
  }
  return hash;
}
