import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'location_service.dart';

/// ChangeNotifier that exposes the latest position. Use `Selector` to rebuild
/// only map markers / distance widgets without triggering full screen rebuilds.
class LocationProvider extends ChangeNotifier {
  LocationProvider({LocationService? service})
      : _service = service ?? LocationService.instance;

  final LocationService _service;

  StreamSubscription<Position>? _sub;
  Position? _position;
  bool _hasPermission = false;

  Position? get position => _position;
  LatLng? get latLng =>
      _position == null ? null : LatLng(_position!.latitude, _position!.longitude);
  bool get hasPermission => _hasPermission;

  Future<void> start({bool requestAlways = true}) async {
    _hasPermission = await _service.requestPermission(
      requestAlways: requestAlways,
    );
    if (!_hasPermission) {
      notifyListeners();
      return;
    }

    _position = await _service.lastKnown() ?? await _service.currentPosition();
    notifyListeners();

    _sub?.cancel();
    _sub = _service.positionStream().listen((pos) {
      _position = pos;
      notifyListeners();
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
