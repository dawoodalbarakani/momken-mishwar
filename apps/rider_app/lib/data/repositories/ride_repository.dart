library rider_app.data.repositories.ride_repository;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/quote_api_model.dart';
import '../models/ride_api_model.dart';
import '../../domain/models/quote.dart';
import '../../domain/models/ride.dart';
import '../services/ride_service.dart;

/// Single source of truth for quotes and rides. Transforms raw API models into
/// clean domain models.
class RideRepository {
  RideRepository({required RideService rideService}) : _rideService = rideService;

  final RideService _rideService;

  /// Fetches a server-computed fare estimate.
  Future<Quote> fetchQuote({required String pickup, required String destination}) async {
    final api = await _rideService.fetchQuote(pickup: pickup, destination: destination);
    return _quoteToDomain(QuoteApiModel.fromJson(api));
  }

  Quote _quoteToDomain(QuoteApiModel api) => Quote(
        id: api.id,
        estimatedAmount: api.estimatedAmount,
        currency: api.currency,
        ruleVersion: api.ruleVersion,
        distanceMeters: api.distanceMeters,
        durationSeconds: api.durationSeconds,
        extraFees: api.extraFees,
      );

  /// Creates a ride request and returns the new ride id.
  Future<String> createRide({
    required String pickup,
    required String destination,
    required String quoteId,
  }) async {
    final api = await _rideService.createRide(
      pickup: pickup,
      destination: destination,
      quoteId: quoteId,
    );
    return RideApiModel.fromJson(api).id;
  }

  /// Cancels a ride. Returns true on success.
  Future<bool> cancelRide(String rideId) async {
    try {
      await _rideService.cancelRide(rideId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Restores ride details (driver, vehicle, start code).
  Future<Ride> getRide(String rideId) async {
    final api = await _rideService.getRide(rideId);
    final model = RideApiModel.fromJson(api);
    return Ride(id: model.id, driverName: model.driverName, vehiclePlate: model.vehiclePlate, startCode: model.startCode);
  }
}

final rideRepositoryProvider = Provider(
  (ref) => RideRepository(rideService: RideService(ref.read(dioClientProvider))),
);
