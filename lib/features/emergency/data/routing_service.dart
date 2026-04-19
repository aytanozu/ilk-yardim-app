import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteResult {
  RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
}

/// Uses OSRM public demo server for MVP. Self-host or swap to Directions
/// once traffic increases.
class RoutingService {
  RoutingService({this.baseUrl = 'https://router.project-osrm.org'});

  final String baseUrl;

  Future<RouteResult?> route({
    required LatLng from,
    required LatLng to,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}'
      '?overview=full&geometries=polyline&alternatives=false',
    );
    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final geom = route['geometry'] as String;
      final decoded = PolylinePoints().decodePolyline(geom);
      final pts = decoded
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();
      return RouteResult(
        points: pts,
        distanceMeters: (route['distance'] as num).toDouble(),
        durationSeconds: (route['duration'] as num).toDouble(),
      );
    } catch (e) {
      debugPrint('OSRM error: $e');
      return null;
    }
  }
}
