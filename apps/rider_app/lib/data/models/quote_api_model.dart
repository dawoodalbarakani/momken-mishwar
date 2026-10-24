library rider_app.data.models.quote_api_model;

/// Raw API model for POST /quotes.
class QuoteApiModel {
  const QuoteApiModel({
    required this.id,
    required this.estimatedAmount,
    required this.currency,
    required this.ruleVersion,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.extraFees,
  });

  final String id;
  final String estimatedAmount;
  final String currency;
  final String ruleVersion;
  final double distanceMeters;
  final int durationSeconds;
  final String extraFees;

  factory QuoteApiModel.fromJson(Map<String, dynamic> json) {
    return QuoteApiModel(
      id: (json['id'] as num?)?.toString() ?? '',
      estimatedAmount: (json['estimated_amount'] as num?)?.toString() ?? '0.00',
      currency: (json['currency'] as String?) ?? 'YER',
      ruleVersion: (json['rule_version'] as String?) ?? '',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      extraFees: (json['extra_fees'] as num?)?.toString() ?? '0.00',
    );
  }
}
