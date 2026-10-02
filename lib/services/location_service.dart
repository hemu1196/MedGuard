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

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LocationPermissionState _permissionState = LocationPermissionState.initial;
  LocationData? _currentLocation;
  SelectedLocation? _selectedLocation;

  LocationPermissionState get permissionState => _permissionState;
  LocationData? get currentLocation => _currentLocation;
  SelectedLocation? get selectedLocation => _selectedLocation;

  Future<SelectedLocation> ensureLocationLoaded() async {
    if (_selectedLocation != null) {
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
        cityName: locData.cityName,
        source: LocationSource.currentGps,
      );
      return _selectedLocation!;
    }

    _selectedLocation ??= SelectedLocation(
      latitude: 17.3850,
      longitude: 78.4867,
      cityName: 'Default Area',
      source: LocationSource.currentGps,
    );
    return _selectedLocation!;
  }

  Future<LocationData?> requestLocation() async {
    _permissionState = LocationPermissionState.requesting;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _permissionState = LocationPermissionState.disabled;
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _permissionState = LocationPermissionState.denied;
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionState = LocationPermissionState.denied;
        return null;
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (e) {
        debugPrint('[LOCATION SERVICE] getCurrentPosition note, attempting last known: $e');
        position = await Geolocator.getLastKnownPosition();
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

        return _currentLocation;
      } else {
        _permissionState = LocationPermissionState.error;
        return null;
      }
    } catch (e) {
      debugPrint('[LOCATION SERVICE] Error fetching location: $e');
      _permissionState = LocationPermissionState.error;
      return null;
    }
  }

  Future<SelectedLocation?> geocodeCity(String cityQuery) async {
    final cleanQuery = cityQuery.trim();
    if (cleanQuery.isEmpty) {
      throw ValidationException('Please enter a valid city or location.');
    }

    try {
      final queryUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&limit=1',
      );
      final response = await http
          .get(queryUrl, headers: {'User-Agent': 'MedGuardAI-App/1.0'})
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
            return _selectedLocation;
          }
        }
      }
      throw AppException('Location not found. Please enter a valid city or location.');
    } catch (e) {
      if (e is AppException) rethrow;
      debugPrint('[LOCATION SERVICE] Geocode error: $e');
      throw AppException('Unable to find location for "$cleanQuery". Please check your connection.');
    }
  }

  void setSelectedLocation(SelectedLocation loc) {
    _selectedLocation = loc;
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
  }
}
