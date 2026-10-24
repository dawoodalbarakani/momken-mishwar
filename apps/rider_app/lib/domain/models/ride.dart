library rider_app.domain.models.ride;

enum RideRequestStatus { idle, searching, driverFound, cancelled, error }

/// Clean domain model for a ride.
class Ride {
  const Ride({
    required this.id,
    this.driverName,
    this.vehiclePlate,
    this.startCode,
  });

  final String id;
  final String? driverName;
  final String? vehiclePlate;
  final String? startCode;
}
