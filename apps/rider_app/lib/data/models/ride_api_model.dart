
/// Raw API model for POST /rides and GET /rides/:id.
class RideApiModel {
  const RideApiModel({
    required this.id,
    this.driverName,
    this.vehiclePlate,
    this.startCode,
  });

  final String id;
  final String? driverName;
  final String? vehiclePlate;
  final String? startCode;

  factory RideApiModel.fromJson(Map<String, dynamic> json) {
    return RideApiModel(
      id: (json['id'] as num?)?.toString() ?? '',
      driverName: json['driver_name'] as String?,
      vehiclePlate: json['vehicle_plate'] as String?,
      startCode: json['start_code'] as String?,
    );
  }
}
