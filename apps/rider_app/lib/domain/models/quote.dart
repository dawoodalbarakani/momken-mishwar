library rider_app.domain.models.quote;

/// Clean domain model for a server-computed fare estimate.
class Quote {
  const Quote({
    required this.id,
    required this.estimatedAmount,
    required this.currency,
    required this.ruleVersion,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.extraFees,
  });

  /// Estimated amount as a decimal string from the server (never trust client-side price).
  final String id;
  final String estimatedAmount;
  final String currency;
  final String ruleVersion;
  final double distanceMeters;
  final int durationSeconds;
  final String extraFees;
}
