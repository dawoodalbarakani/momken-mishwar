library rider_app.core.map_provider;

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/constants.dart';

/// Result of a place search (neighborhood / landmark).
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

/// A polyline route between two points.
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

/// Live driver location with data age (so stale locations are never shown as live).
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

/// Abstraction over a map provider (Google Maps / Mapbox / stub).
///
/// The default [StubMapProvider] throws [UnimplementedError] and MUST be
/// replaced by a real provider before shipping. The real provider's API key
/// must come from the provider console (e.g. Google Cloud Console) and MUST
/// never be committed to this repository. See README-ESETUP.md.
abstract class MapProvider {
  /// Pick a location on the map (user taps a point).
  Future<LatLng> pickLocation();

  /// Search places by query (neighborhood / landmark).
  Future<List<PlaceResult>> searchPlaces(String query);

  /// Get a route between two points.
  Future<RouteResult> getRoute(LatLng origin, LatLng destination);

  /// Watch live driver location stream with data age.
  Stream<DriverLocation> watchDriverLocation(String rideId);
}

/// Default stub implementation. Every method throws [UnimplementedError].
class StubMapProvider implements MapProvider {
  @override
  Future<LatLng> pickLocation() =>
      throw UnimplementedError('StubMapProvider.pickLocation: replace with a real map provider (Google Maps / Mapbox).');

  @override
  Future<List<PlaceResult>> searchPlaces(String query) =>
      throw UnimplementedError('StubMapProvider.searchPlaces: replace with a real map provider.');

  @override
  Future<RouteResult> getRoute(LatLng origin, LatLng destination) =>
      throw UnimplementedError('StubMapProvider.getRoute: replace with a real map provider.');

  @override
  Stream<DriverLocation> watchDriverLocation(String rideId) async* {
    throw UnimplementedError('StubMapProvider.watchDriverLocation: replace with a real map provider.');
  }
}
