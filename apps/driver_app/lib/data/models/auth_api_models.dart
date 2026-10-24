library driver_app.data.models.auth_api_models;

class OtpVerifyApiModel {
  const OtpVerifyApiModel({required this.accessToken, this.refreshToken});

  final String accessToken;
  final String? refreshToken;

  factory OtpVerifyApiModel.fromJson(Map<String, dynamic> json) {
    return OtpVerifyApiModel(
      accessToken: (json['access_token'] as String?) ?? '',
      refreshToken: json['refresh_token'] as String?,
    );
  }
}

class DriverMeApiModel {
  const DriverMeApiModel({
    required this.id,
    required this.phone,
    this.name,
    this.verificationStatus,
  });

  final String id;
  final String phone;
  final String? name;
  final String? verificationStatus;

  factory DriverMeApiModel.fromJson(Map<String, dynamic> json) {
    return DriverMeApiModel(
      id: (json['id'] as num?)?.toString() ?? '',
      phone: (json['phone'] as num?)?.toString() ?? '',
      name: json['name'] as String?,
      verificationStatus: json['verification_status'] as String?,
    );
  }
}

class AvailableRideApiModel {
  const AvailableRideApiModel({
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
  final String expiresAt;

  factory AvailableRideApiModel.fromJson(Map<String, dynamic> json) {
    return AvailableRideApiModel(
      rideId: (json['ride_id'] as num?)?.toString() ?? '',
      pickup: (json['pickup'] as num?)?.toString() ?? '',
      destination: (json['destination'] as num?)?.toString() ?? '',
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      expiresAt: json['expires_at']?.toString() ?? '',
    );
  }
}

class OfferApiModel {
  const OfferApiModel({
    required this.offerId,
    required this.rideId,
    required this.pickup,
    required this.destination,
    required this.fare,
    required this.distanceMeters,
    required this.expiresAt,
    this.status,
  });

  final String offerId;
  final String rideId;
  final String pickup;
  final String destination;
  final double fare;
  final double distanceMeters;
  final String expiresAt;
  final String? status;

  factory OfferApiModel.fromJson(Map<String, dynamic> json) {
    return OfferApiModel(
      offerId: (json['offer_id'] as num?)?.toString() ?? '',
      rideId: (json['ride_id'] as num?)?.toString() ?? '',
      pickup: (json['pickup'] as num?)?.toString() ?? '',
      destination: (json['destination'] as num?)?.toString() ?? '',
      fare: (json['fare'] as num?)?.toDouble() ?? 0,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0,
      expiresAt: json['expires_at']?.toString() ?? '',
      status: json['status'] as String?,
    );
  }
}

class RideApiModel {
  const RideApiModel({
    required this.id,
    this.status,
    this.pickup,
    this.destination,
    this.customerName,
    this.customerPhone,
    this.startCode,
    this.driverAssigned,
  });

  final String id;
  final String? status;
  final String? pickup;
  final String? destination;
  final String? customerName;
  final String? customerPhone;
  final String? startCode;
  final bool? driverAssigned;

  factory RideApiModel.fromJson(Map<String, dynamic> json) {
    return RideApiModel(
      id: (json['id'] as num?)?.toString() ?? '',
      status: json['status'] as String?,
      pickup: json['pickup'] as String?,
      destination: json['destination'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      startCode: json['start_code'] as String?,
      driverAssigned: json['driver_assigned'] as bool?,
    );
  }
}

class EarningsApiModel {
  const EarningsApiModel({
    required this.totalFare,
    required this.platformCommission,
    required this.netPayable,
    required this.cashCollected,
    required this.platformReceivables,
    required this.rides,
  });

  final double totalFare;
  final double platformCommission;
  final double netPayable;
  final double cashCollected;
  final double platformReceivables;
  final List<Map<String, dynamic>> rides;

  factory EarningsApiModel.fromJson(Map<String, dynamic> json) {
    return EarningsApiModel(
      totalFare: (json['total_fare'] as num?)?.toDouble() ?? 0,
      platformCommission: (json['platform_commission'] as num?)?.toDouble() ?? 0,
      netPayable: (json['net_payable'] as num?)?.toDouble() ?? 0,
      cashCollected: (json['cash_collected'] as num?)?.toDouble() ?? 0,
      platformReceivables: (json['platform_receivables'] as num?)?.toDouble() ?? 0,
      rides: (json['rides'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
    );
  }
}
