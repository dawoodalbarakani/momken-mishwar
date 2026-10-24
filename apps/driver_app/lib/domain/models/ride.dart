library driver_app.domain.models.ride;

enum RideStatus { assigned, arriving, arrived, inProgress, completed, cancelled }

class RideCancellation {
  const RideCancellation({required this.reason, required this.actor, required this.cancelledAt});

  final String reason;
  final String actor;
  final DateTime cancelledAt;
}

class Ride {
  const Ride({
    required this.id,
    this.status = RideStatus.assigned,
    this.pickup,
    this.destination,
    this.customerName,
    this.customerPhone,
    this.startCode,
    this.verifiedAssignment = false,
    this.started = false,
    this.completed = false,
    this.cancellation,
  });

  final String id;
  final RideStatus status;
  final String? pickup;
  final String? destination;
  final String? customerName;
  final String? customerPhone;
  final String? startCode;
  final bool verifiedAssignment;
  final bool started;
  final bool completed;
  final RideCancellation? cancellation;

  bool get canStart => verifiedAssignment && !started && status == RideStatus.assigned;
  bool get canComplete => started && status == RideStatus.inProgress && !completed;
}
