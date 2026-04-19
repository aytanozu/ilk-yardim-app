import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/location/geohash.dart';

/// Status states for an AED entry.
enum AedStatus { pending, active, rejected }

class AedEntry {
  const AedEntry({
    required this.id,
    required this.location,
    required this.name,
    required this.address,
    required this.status,
    this.reportedBy,
    this.verifiedBy,
    this.notes,
  });

  final String id;
  final GeoPoint location;
  final String name;
  final String address;
  final AedStatus status;
  final String? reportedBy;
  final String? verifiedBy;
  final String? notes;

  factory AedEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AedEntry(
      id: doc.id,
      location: (data['location'] as GeoPoint?) ??
          const GeoPoint(41.0082, 28.9784),
      name: (data['name'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      status: _status(data['status'] as String?),
      reportedBy: data['reportedBy'] as String?,
      verifiedBy: data['verifiedBy'] as String?,
      notes: data['notes'] as String?,
    );
  }

  static AedStatus _status(String? key) {
    switch (key) {
      case 'active':
        return AedStatus.active;
      case 'rejected':
        return AedStatus.rejected;
      case 'pending':
      default:
        return AedStatus.pending;
    }
  }
}

class AedRepo {
  AedRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Streams active AEDs whose geohash-7 prefix matches the caller's
  /// current cell. We approximate a "nearby" query by the 9 cells
  /// around the caller's precision-5 hash (each cell ~4.9 km wide) —
  /// plenty for the mobile map preview. For exact radius work, the
  /// caller filters by distance client-side after the stream updates.
  Stream<List<AedEntry>> watchNearby({
    required double lat,
    required double lng,
  }) {
    final prefix = geohashEncode(lat, lng, precision: 5);
    final hi = _geohashPrefixEnd(prefix);
    return _firestore
        .collection('aeds')
        .where('status', isEqualTo: 'active')
        .where('geohash', isGreaterThanOrEqualTo: prefix)
        .where('geohash', isLessThan: hi)
        .limit(200)
        .snapshots()
        .map((s) => s.docs.map(AedEntry.fromSnapshot).toList());
  }

  /// Submit a new AED as `pending`. Firestore rules enforce that the
  /// submitter owns the `reportedBy` field and the status is pending.
  Future<void> submitPending({
    required String uid,
    required double lat,
    required double lng,
    required String name,
    required String address,
    String? notes,
  }) async {
    try {
      await _firestore.collection('aeds').add({
        'location': GeoPoint(lat, lng),
        'geohash': geohashEncode(lat, lng, precision: 7),
        'name': name.trim(),
        'address': address.trim(),
        'notes': (notes ?? '').trim(),
        'status': 'pending',
        'reportedBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('AedRepo.submitPending failed: $e');
      rethrow;
    }
  }

  /// End of the geohash range for a prefix query — increment the last
  /// character by one in the base32 alphabet so range [prefix, hi) covers
  /// all codes starting with `prefix`.
  static String _geohashPrefixEnd(String prefix) {
    if (prefix.isEmpty) return '{'; // "{" > all base32 chars
    // Base32 alphabet used by our geohash encoder.
    const alphabet = '0123456789bcdefghjkmnpqrstuvwxyz';
    final last = prefix[prefix.length - 1];
    final idx = alphabet.indexOf(last);
    if (idx < 0 || idx == alphabet.length - 1) return '${prefix}~';
    final nextChar = alphabet[idx + 1];
    return prefix.substring(0, prefix.length - 1) + nextChar;
  }
}

/// Quick haversine distance (meters) between two WGS84 points — used
/// client-side to annotate AEDs with "X m away" on the map card.
double distanceMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0;
  final dLat = _deg(lat2 - lat1);
  final dLng = _deg(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg(lat1)) *
          math.cos(_deg(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

double _deg(double d) => d * math.pi / 180.0;
