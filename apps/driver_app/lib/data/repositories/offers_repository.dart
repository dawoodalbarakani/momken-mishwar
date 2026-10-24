
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/offer.dart';
import '../services/dio_client.dart';
import '../services/offers_service.dart';

class OffersRepository {
  OffersRepository({required OffersService offersService}) : _offersService = offersService;

  final OffersService _offersService;

  Future<List<Offer>> fetchOffers() async {
    final list = await _offersService.getOffers();
    return list
        .map((e) => Offer(
              offerId: e['offer_id']?.toString() ?? '',
              rideId: e['ride_id']?.toString() ?? '',
              pickup: e['pickup']?.toString() ?? '',
              destination: e['destination']?.toString() ?? '',
              fare: (e['fare'] as num?)?.toDouble() ?? 0,
              distanceMeters: (e['distance_meters'] as num?)?.toDouble() ?? 0,
              expiresAt: e['expires_at'] != null
                  ? DateTime.tryParse(e['expires_at'].toString()) ?? DateTime.now().add(const Duration(minutes: 5))
                  : DateTime.now().add(const Duration(minutes: 5)),
              status: _parseStatus(e['status']),
            ))
        .where((o) => !o.isExpired)
        .toList();
  }

  Future<bool> acceptOffer(String offerId, {required String rideId, required String idempotencyKey}) async {
    try {
      await _offersService.acceptOffer(offerId, rideId: rideId, idempotencyKey: idempotencyKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectOffer(String offerId) async {
    try {
      await _offersService.rejectOffer(offerId);
      return true;
    } catch (_) {
      return false;
    }
  }

  OfferStatus _parseStatus(dynamic v) {
    switch (v?.toString().toLowerCase()) {
      case 'accepted':
        return OfferStatus.accepted;
      case 'rejected':
        return OfferStatus.rejected;
      case 'expired':
        return OfferStatus.expired;
      default:
        return OfferStatus.pending;
    }
  }
}

final offersRepositoryProvider = Provider(
  (ref) => OffersRepository(offersService: OffersService(ref.read(dioClientProvider))),
);
