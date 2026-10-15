import 'package:flutter/foundation.dart';
import '../models/hospital.dart';
import '../models/selected_location.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';

class HospitalRepository extends ChangeNotifier {
  static final HospitalRepository instance = HospitalRepository._internal();
  factory HospitalRepository() => instance;
  HospitalRepository._internal();

  final HospitalService _hospitalService = HospitalService();
  final LocationService _locationService = LocationService();

  HospitalSearchResult? _lastResult;
  SelectedLocation? _selectedLocation;
  Hospital? _selectedHospital;
  bool _isLoading = false;
  String? _errorMessage;
  String _loadingStatus = 'Discovering healthcare facilities...';

  HospitalSearchResult? get lastResult => _lastResult;
  List<Hospital> get hospitals => _lastResult?.hospitals ?? [];
  SelectedLocation? get selectedLocation => _selectedLocation ?? _locationService.selectedLocation;
  Hospital? get selectedHospital => _selectedHospital;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get loadingStatus => _loadingStatus;
  int get maxRadiusMeters => _lastResult?.maxRadiusMeters ?? 5000;

  void selectHospital(Hospital? hospital) {
    _selectedHospital = hospital;
    notifyListeners();
  }

  /// Searches hospitals for a specified or active SelectedLocation
  Future<HospitalSearchResult> searchHospitalsForLocation(
    SelectedLocation location, {
    Function(String status)? onProgress,
    bool forceRefresh = false,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _selectedLocation = location;
    _locationService.setSelectedLocation(location);
    _loadingStatus = location.isGps
        ? 'Finding nearby hospitals...'
        : 'Searching hospitals near ${location.cityName ?? "location"}...';
    notifyListeners();

    try {
      final result = await _hospitalService.searchHospitalsForLocation(
        location,
        onProgress: (status) {
          _loadingStatus = status;
          onProgress?.call(status);
          notifyListeners();
        },
        forceRefresh: forceRefresh,
      );

      _lastResult = result;
      _selectedLocation = result.location;
      if (result.hospitals.isNotEmpty) {
        if (_selectedHospital == null || !result.hospitals.any((h) => h.id == _selectedHospital!.id)) {
          _selectedHospital = result.hospitals.first;
        }
      } else {
        _selectedHospital = null;
      }
      _isLoading = false;
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AppException: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Searches hospitals in a specified city
  Future<HospitalSearchResult> searchByCity(
    String cityName, {
    Function(String status)? onProgress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _loadingStatus = 'Finding location for "$cityName"...';
    notifyListeners();

    try {
      final loc = await _locationService.geocodeCity(cityName);
      if (loc == null) {
        throw Exception('Location "$cityName" could not be verified.');
      }
      return await searchHospitalsForLocation(loc, onProgress: onProgress);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Resolves current GPS position and discovers nearby healthcare facilities
  Future<HospitalSearchResult> useCurrentGpsLocation({
    bool forceRefresh = true,
    Function(String status)? onProgress,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _loadingStatus = 'Acquiring GPS location...';
    notifyListeners();

    try {
      final loc = await _locationService.getCurrentGpsLocation();
      return await searchHospitalsForLocation(loc, forceRefresh: forceRefresh, onProgress: onProgress);
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Backward-compatible search method
  Future<List<Hospital>> searchHospitals({
    double? latitude,
    double? longitude,
    String? city,
    Function(String status)? onProgress,
  }) async {
    if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
      final loc = SelectedLocation(
        latitude: latitude,
        longitude: longitude,
        cityName: city ?? 'Current Location',
        source: city != null ? LocationSource.citySearch : LocationSource.currentGps,
      );
      final res = await searchHospitalsForLocation(loc, onProgress: onProgress);
      return res.hospitals;
    } else if (city != null && city.trim().isNotEmpty) {
      final res = await searchByCity(city, onProgress: onProgress);
      return res.hospitals;
    }
    return hospitals;
  }

  /// Backward-compatible progressive search method
  Future<HospitalSearchResult> searchHospitalsProgressive({
    required double latitude,
    required double longitude,
    Function(String status)? onProgress,
  }) async {
    final loc = SelectedLocation(
      latitude: latitude,
      longitude: longitude,
      cityName: 'Current Location',
      source: LocationSource.currentGps,
    );
    return await searchHospitalsForLocation(loc, onProgress: onProgress);
  }
}
