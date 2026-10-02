import '../models/hospital.dart';
import '../models/selected_location.dart';
import '../services/hospital_service.dart';

class HospitalRepository {
  final HospitalService _hospitalService = HospitalService();

  Future<List<Hospital>> searchHospitals({
    double? latitude,
    double? longitude,
    String? city,
    Function(String status)? onProgress,
  }) async {
    return await _hospitalService.fetchNearbyHospitals(
      latitude: latitude,
      longitude: longitude,
      city: city,
      onProgress: onProgress,
    );
  }

  Future<HospitalSearchResult> searchHospitalsProgressive({
    required double latitude,
    required double longitude,
    Function(String status)? onProgress,
  }) async {
    return await _hospitalService.fetchNearbyHospitalsProgressive(
      latitude: latitude,
      longitude: longitude,
      onProgress: onProgress,
    );
  }

  Future<HospitalSearchResult> searchHospitalsForLocation(
    SelectedLocation location, {
    Function(String status)? onProgress,
    bool forceRefresh = false,
  }) async {
    return await _hospitalService.searchHospitalsForLocation(
      location,
      onProgress: onProgress,
      forceRefresh: forceRefresh,
    );
  }
}
