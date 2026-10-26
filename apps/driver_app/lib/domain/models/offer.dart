
enum OfferStatus { pending, accepted, rejected, expired }

class Offer {
  const Offer({
    required this.offerId,
    required this.rideId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceMeters,
    required this.expiresAt,
    this.status = OfferStatus.pending,
  });

  final String offerId;
  final String rideId;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceMeters;
  final DateTime expiresAt;
  final OfferStatus status;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Offer copyWith({OfferStatus? status}) {
    return Offer(
      offerId: offerId,
      rideId: rideId,
      pickup: pickup,
      destination: destination,
      fare: fare,
      distanceMeters: distanceMeters,
      expiresAt: expiresAt,
      status: status ?? this.status,
    );
  }
}
