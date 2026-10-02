class Hospital {
  final String id;
  final String name;
  final String address;
  final double distanceKm;
  final String phone;
  final bool hasEmergencyServices;
  final double latitude;
  final double longitude;
  final bool isDemoData;

  Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.distanceKm,
    required this.phone,
    required this.hasEmergencyServices,
    required this.latitude,
    required this.longitude,
    this.isDemoData = true,
  });
}
