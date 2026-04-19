// Dart port of the geohash encoder matching the Web/admin and geofire-common.

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

String geohashEncode(double lat, double lng, {int precision = 7}) {
  double latMin = -90, latMax = 90, lngMin = -180, lngMax = 180;
  int bit = 0;
  int ch = 0;
  var even = true;
  final buffer = StringBuffer();

  while (buffer.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (lng >= mid) {
        ch = (ch << 1) | 1;
        lngMin = mid;
      } else {
        ch <<= 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (lat >= mid) {
        ch = (ch << 1) | 1;
        latMin = mid;
      } else {
        ch <<= 1;
        latMax = mid;
      }
    }
    even = !even;
    bit++;
    if (bit == 5) {
      buffer.write(_base32[ch]);
      bit = 0;
      ch = 0;
    }
  }
  return buffer.toString();
}
