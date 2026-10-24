library driver_app.data.repositories.map_repository;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/map_service.dart';

class MapRepository {
  MapRepository({required MapService mapService}) : _mapService = mapService;

  final MapService _mapService;

  Future<List<PlaceResult>> searchPlaces(String query) => _mapService.searchPlaces(query);

  Future<LatLng> pickLocation() => _mapService.pickLocation();

  Future<RouteResult> getRoute(LatLng origin, LatLng destination) => _mapService.getRoute(origin, destination);

  Stream<DriverLocation> watchDriverLocation(String rideId) => _mapService.watchDriverLocation(rideId);
}

final mapRepositoryProvider = Provider(
  (ref) => MapRepository(mapService: ref.read(mapServiceProvider)),
);
