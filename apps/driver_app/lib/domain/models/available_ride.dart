library driver_app.domain.models.available_ride;

class AvailableRide {
  const AvailableRide({
    required this.rideId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceMeters,
    required this.expiresAt,
  });

  final String rideId;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceMeters;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

enum AvailabilityStatus { online, offline }

class EarningsSummary {
  const EarningsSummary({
    required this.totalFare,
    required this.completedRides,
    required this.cashCollected,
  });

  final double totalFare;
  final int completedRides;
  final double cashCollected;
}
