library driver_app.data.services.map_service;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PlaceResult {
  const PlaceResult({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latLng,
  });
  final String placeId;
  final String name;
  final String address;
  final LatLng latLng;
}

class RouteResult {
  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
}

class DriverLocation {
  const DriverLocation({
    required this.latLng,
    required this.recordedAt,
    required this.ageSeconds,
  });
  final LatLng latLng;
  final DateTime recordedAt;
  final int ageSeconds;
}

abstract class MapService {
  Future<LatLng> pickLocation();
  Future<List<PlaceResult>> searchPlaces(String query);
  Future<RouteResult> getRoute(LatLng origin, LatLng destination);
  Stream<DriverLocation> watchDriverLocation(String rideId);
}

class StubMapService implements MapService {
  @override
  Future<LatLng> pickLocation() =>
      throw UnimplementedError('StubMapService.pickLocation: replace with a real map provider. See README-SETUP.md.');

  @override
  Future<List<PlaceResult>> searchPlaces(String query) =>
      throw UnimplementedError('StubMapService.searchPlaces: replace with a real map provider. See README-SETUP.md.');

  @override
  Future<RouteResult> getRoute(LatLng origin, LatLng destination) =>
      throw UnimplementedError('StubMapService.getRoute: replace with a real map provider. See README-SETUP.md.');

  @override
  Stream<DriverLocation> watchDriverLocation(String rideId) async* {
    throw UnimplementedError('StubMapService.watchDriverLocation: replace with a real map provider. See README-SETUP.md.');
  }
}

final mapServiceProvider = Provider((ref) => StubMapService());
