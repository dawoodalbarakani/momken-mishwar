
class CompletedRide {
  const CompletedRide({
    required this.rideId,
    required this.fare,
    required this.platformCommission,
    required this.netToDriver,
    required this.cashCollected,
    required this.completedAt,
  });

  final String rideId;
  final double fare;
  final double platformCommission;
  final double netToDriver;
  final double cashCollected;
  final DateTime completedAt;
}

class EarningsState {
  const EarningsState({
    this.completedRides = const [],
    this.totalFare = 0,
    this.platformCommission = 0,
    this.netPayable = 0,
    this.cashCollected = 0,
    this.platformReceivables = 0,
    this.isLoading = false,
    this.error,
  });

  final List<CompletedRide> completedRides;
  final double totalFare;
  final double platformCommission;
  final double netPayable;
  final double cashCollected;
  final double platformReceivables;
  final bool isLoading;
  final String? error;

  EarningsState copyWith({
    List<CompletedRide>? completedRides,
    double? totalFare,
    double? platformCommission,
    double? netPayable,
    double? cashCollected,
    double? platformReceivables,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return EarningsState(
      completedRides: completedRides ?? this.completedRides,
      totalFare: totalFare ?? this.totalFare,
      platformCommission: platformCommission ?? this.platformCommission,
      netPayable: netPayable ?? this.netPayable,
      cashCollected: cashCollected ?? this.cashCollected,
      platformReceivables: platformReceivables ?? this.platformReceivables,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
