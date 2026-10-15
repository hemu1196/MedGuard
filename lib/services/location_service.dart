import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/errors/app_exception.dart';
import '../models/selected_location.dart';

class LocationData {
  final double latitude;
  final double longitude;
  final String? cityName;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.cityName,
  });

  String? get address => cityName;
  String get mapsUrl => 'https://maps.google.com/?q=$latitude,$longitude';
}

enum LocationPermissionState {
  initial,
  requesting,
  granted,
  denied,
  disabled,
  error,
}

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationPermissionState _permissionState = LocationPermissionState.initial;
  LocationData? _currentLocation;
  SelectedLocation? _selectedLocation;

  LocationPermissionState get permissionState => _permissionState;
  LocationData? get currentLocation => _currentLocation;
  SelectedLocation? get selectedLocation => _selectedLocation;

  bool get hasLocation => _selectedLocation != null && _selectedLocation!.latitude != 0.0;

  Future<SelectedLocation> ensureLocationLoaded() async {
    if (_selectedLocation != null && _selectedLocation!.latitude != 0.0) {
      return _selectedLocation!;
    }
    return await getCurrentGpsLocation();
  }

  Future<SelectedLocation> getCurrentGpsLocation() async {
    final locData = await requestLocation();
    if (locData != null) {
      _selectedLocation = SelectedLocation(
        latitude: locData.latitude,
        longitude: locData.longitude,
        cityName: locData.cityName ?? 'Current Location',
        source: LocationSource.currentGps,
      );
      notifyListeners();
      return _selectedLocation!;
    }

    if (_selectedLocation != null && _selectedLocation!.latitude != 0.0) {
      return _selectedLocation!;
    }

    if (_permissionState == LocationPermissionState.disabled) {
      throw AppException('Device location services (GPS) are turned off. Please turn on GPS.');
    } else if (_permissionState == LocationPermissionState.denied) {
      throw AppException('Location permission was denied. Please grant location access or search by city.');
    } else {
      throw AppException('Unable to determine GPS location. Please check settings or search by city.');
    }
  }

  Future<LocationData?> requestLocation() async {
    _permissionState = LocationPermissionState.requesting;
    notifyListeners();

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionState = LocationPermissionState.disabled;
        notifyListeners();
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _permissionState = LocationPermissionState.denied;
          notifyListeners();
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionState = LocationPermissionState.denied;
        notifyListeners();
        return null;
      }

      Position? position;

      // Tier 1: Try high accuracy with 8s timeout
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('[LOCATION SERVICE] High-accuracy fix note: $e. Retrying medium accuracy...');
      }

      // Tier 2: Try medium accuracy with 4s timeout if high accuracy timed out
      if (position == null) {
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );
        } catch (e) {
          debugPrint('[LOCATION SERVICE] Medium accuracy fix note: $e. Trying last known...');
        }
      }

      // Tier 3: Last known position fallback
      if (position == null) {
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (e) {
          debugPrint('[LOCATION SERVICE] Last known position failed: $e');
        }
      }

      if (position != null) {
        _permissionState = LocationPermissionState.granted;
        _currentLocation = LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          cityName:
              'GPS Location (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)})',
        );

        _selectedLocation = SelectedLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          cityName: 'Current Location',
          source: LocationSource.currentGps,
        );

        notifyListeners();
        return _currentLocation;
      } else {
        _permissionState = LocationPermissionState.error;
        notifyListeners();
        return null;
      }
    } catch (e) {
      debugPrint('[LOCATION SERVICE] Exception requesting location: $e');
      _permissionState = LocationPermissionState.error;
      notifyListeners();
      return null;
    }
  }

  Future<SelectedLocation?> geocodeCity(String cityQuery) async {
    final cleanQuery = cityQuery.trim();
    if (cleanQuery.isEmpty) {
      throw ValidationException('Please enter a valid city or location name.');
    }

    try {
      final queryUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=1',
      );
      final response = await http
          .get(queryUrl, headers: {
            'User-Agent': 'MEDGUARD-Healthcare-Assistant/2.0 (contact@medguard.app)',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final item = data.first;
          final double lat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final double lon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;
          final String rawName = item['display_name'] ?? cleanQuery;
          final String displayName = rawName.split(',').first.trim();

          if (lat != 0.0 && lon != 0.0) {
            _selectedLocation = SelectedLocation(
              latitude: lat,
              longitude: lon,
              cityName: displayName.isNotEmpty ? displayName : cleanQuery,
              source: LocationSource.citySearch,
            );
            _currentLocation = LocationData(
              latitude: lat,
              longitude: lon,
              cityName: _selectedLocation!.cityName,
            );
            _permissionState = LocationPermissionState.granted;
            notifyListeners();
            return _selectedLocation;
          }
        }
      }
      throw AppException('Location "$cleanQuery" was not found. Please check the spelling.');
    } catch (e) {
      if (e is AppException) rethrow;
      debugPrint('[LOCATION SERVICE] Geocode error: $e');
      throw AppException('Unable to find location for "$cleanQuery". Please check your connection.');
    }
  }

  void setSelectedLocation(SelectedLocation loc) {
    _selectedLocation = loc;
    _currentLocation = LocationData(
      latitude: loc.latitude,
      longitude: loc.longitude,
      cityName: loc.cityName,
    );
    notifyListeners();
  }

  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  void setManualCity(String city, {double? lat, double? lng}) {
    _permissionState = LocationPermissionState.granted;
    final l = lat ?? _currentLocation?.latitude ?? 0.0;
    final lg = lng ?? _currentLocation?.longitude ?? 0.0;
    _currentLocation = LocationData(
      latitude: l,
      longitude: lg,
      cityName: city,
    );
    _selectedLocation = SelectedLocation(
      latitude: l,
      longitude: lg,
      cityName: city,
      source: LocationSource.citySearch,
    );
    notifyListeners();
  }
}
