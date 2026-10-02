import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/errors/app_exception.dart';
import '../models/hospital.dart';
import '../models/selected_location.dart';

class HospitalSearchResult {
  final List<Hospital> hospitals;
  final int maxRadiusMeters;
  final String? city;
  final String statusMessage;
  final SelectedLocation location;
  final String searchSource;

  HospitalSearchResult({
    required this.hospitals,
    required this.maxRadiusMeters,
    this.city,
    required this.statusMessage,
    required this.location,
    required this.searchSource,
  });
}

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  HospitalSearchResult? _lastSearchResult;
  HospitalSearchResult? get lastSearchResult => _lastSearchResult;

  Future<HospitalSearchResult> searchHospitalsForLocation(
    SelectedLocation location, {
    Function(String status)? onProgress,
  }) async {
    final result = await fetchNearbyHospitalsProgressive(
      location: location,
      onProgress: onProgress,
    );

    if (result.hospitals.isEmpty && location.cityName != null && location.cityName!.trim().isNotEmpty) {
      final cityHospitals = await fetchNearbyHospitals(
        latitude: location.latitude,
        longitude: location.longitude,
        city: location.cityName,
        onProgress: onProgress,
      );
      final combined = HospitalSearchResult(
        hospitals: cityHospitals,
        maxRadiusMeters: 50000,
        city: location.cityName,
        statusMessage: cityHospitals.isNotEmpty
            ? 'Found ${cityHospitals.length} hospitals near ${location.cityName}.'
            : 'No hospitals found near ${location.cityName}.',
        location: location,
        searchSource: location.isGps ? 'gps' : 'city',
      );
      _lastSearchResult = combined;
      return combined;
    }

    _lastSearchResult = result;
    return result;
  }

  /// Progressively searches nearby real hospitals from user's coordinates or selected location.
  /// Radii steps: 5 km, 10 km, 25 km, 50 km.
  /// Stops when at least 5 hospitals are found or 50 km max radius is reached.
  Future<HospitalSearchResult> fetchNearbyHospitalsProgressive({
    double? latitude,
    double? longitude,
    SelectedLocation? location,
    Function(String status)? onProgress,
  }) async {
    final double lat = location?.latitude ?? latitude ?? 17.3850;
    final double lng = location?.longitude ?? longitude ?? 78.4867;
    final SelectedLocation activeLoc = location ??
        SelectedLocation(
          latitude: lat,
          longitude: lng,
          cityName: 'Current Location',
          source: LocationSource.currentGps,
        );

    final Map<String, Hospital> deduplicatedMap = {};
    final List<int> progressiveRadii = [5000, 10000, 25000, 50000];
    int currentRadius = 5000;

    for (final radius in progressiveRadii) {
      currentRadius = radius;
      final radiusKm = radius ~/ 1000;
      onProgress?.call('Searching within $radiusKm km...');

      try {
        final overpassUrl = Uri.parse(
          'https://overpass-api.de/api/interpreter?data=[out:json][timeout:10];(node(around:$radius,$lat,$lng)[amenity~"hospital|clinic"];way(around:$radius,$lat,$lng)[amenity~"hospital|clinic"];);out%20center%2030;',
        );

        final response = await http.get(overpassUrl).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List elements = data['elements'] ?? [];

          for (var i = 0; i < elements.length; i++) {
            final item = elements[i];
            final tags = item['tags'] ?? {};

            final itemLat = (item['lat'] as num?)?.toDouble() ??
                (item['center']?['lat'] as num?)?.toDouble() ??
                lat;
            final itemLon = (item['lon'] as num?)?.toDouble() ??
                (item['center']?['lon'] as num?)?.toDouble() ??
                lng;

            final String rawName = tags['name'] ?? tags['operator'] ?? tags['name:en'] ?? 'Hospital / Medical Center';
            final String name = rawName.trim();
            final String street = tags['addr:street'] ?? tags['addr:full'] ?? tags['addr:suburb'] ?? tags['addr:city'] ?? 'Healthcare Facility';
            final String rawPhone = tags['phone'] ?? tags['contact:phone'] ?? tags['mobile'] ?? '';
            final String phone = rawPhone.trim();

            final double distanceMeters = Geolocator.distanceBetween(
              lat,
              lng,
              itemLat,
              itemLon,
            );
            final double distanceKm = distanceMeters / 1000.0;

            final String uniqueId = item['id'] != null
                ? 'osm_${item['id']}'
                : '${name}_${itemLat.toStringAsFixed(3)}_${itemLon.toStringAsFixed(3)}';

            if (!deduplicatedMap.containsKey(uniqueId)) {
              deduplicatedMap[uniqueId] = Hospital(
                id: uniqueId,
                name: name,
                address: street,
                distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
                phone: phone,
                hasEmergencyServices: tags['emergency'] == 'yes' || tags['amenity'] == 'hospital',
                latitude: itemLat,
                longitude: itemLon,
                isDemoData: false,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[HOSPITAL SERVICE] Progressive search note at ${radius}m: $e');
      }

      final sortedList = deduplicatedMap.values.toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      if (sortedList.length >= 5 || radius == 50000) {
        return HospitalSearchResult(
          hospitals: sortedList,
          maxRadiusMeters: currentRadius,
          statusMessage: sortedList.isNotEmpty
              ? 'Found ${sortedList.length} hospitals within ${currentRadius ~/ 1000} km.'
              : 'No hospitals found within 50 km.',
          location: activeLoc,
          searchSource: activeLoc.isGps ? 'gps' : 'city',
        );
      }
    }

    final sortedList = deduplicatedMap.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return HospitalSearchResult(
      hospitals: sortedList,
      maxRadiusMeters: currentRadius,
      statusMessage: sortedList.isNotEmpty
          ? 'Found ${sortedList.length} hospitals within ${currentRadius ~/ 1000} km.'
          : 'No hospitals found nearby.',
      location: activeLoc,
      searchSource: activeLoc.isGps ? 'gps' : 'city',
    );
  }

  /// Fetches nearby hospitals by coordinates or city search.
  Future<List<Hospital>> fetchNearbyHospitals({
    double? latitude,
    double? longitude,
    String? city,
    Function(String status)? onProgress,
  }) async {
    try {
      if (latitude != null && longitude != null) {
        final result = await fetchNearbyHospitalsProgressive(
          latitude: latitude,
          longitude: longitude,
          onProgress: onProgress,
        );
        if (result.hospitals.isNotEmpty) {
          return result.hospitals;
        }
      }

      if (city != null && city.trim().isNotEmpty) {
        onProgress?.call('Searching hospitals in $city...');
        final queryUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=hospitals+in+${Uri.encodeComponent(city)}&format=json&limit=15',
        );
        final response = await http
            .get(queryUrl, headers: {'User-Agent': 'MedGuardAI-App/1.0'})
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final List data = json.decode(response.body);
          final List<Hospital> realHospitals = [];

          for (var i = 0; i < data.length; i++) {
            final item = data[i];
            final displayName = item['display_name'] ?? city;
            final nameParts = displayName.split(',');
            final hospitalName = nameParts.first.trim();
            final address = nameParts.skip(1).take(2).join(',').trim();
            final itemLat = double.tryParse(item['lat'] ?? '') ?? 0.0;
            final itemLon = double.tryParse(item['lon'] ?? '') ?? 0.0;

            double distKm = 2.0 + (i * 1.1);
            if (latitude != null && longitude != null && itemLat != 0.0 && itemLon != 0.0) {
              distKm = Geolocator.distanceBetween(latitude, longitude, itemLat, itemLon) / 1000.0;
            }

            realHospitals.add(
              Hospital(
                id: 'osm_city_${item['place_id'] ?? i}',
                name: hospitalName,
                address: address.isNotEmpty ? address : city,
                distanceKm: double.parse(distKm.toStringAsFixed(1)),
                phone: '',
                hasEmergencyServices: true,
                latitude: itemLat,
                longitude: itemLon,
                isDemoData: false,
              ),
            );
          }

          realHospitals.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
          return realHospitals;
        }
      }

      return [];
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE ERROR] Real hospital API request failed: $e');
      throw NetworkException('Unable to search nearby hospitals. Please verify your connection.');
    }
  }
}
