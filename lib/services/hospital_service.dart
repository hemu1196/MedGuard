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

class _CacheEntry {
  final HospitalSearchResult result;
  final DateTime timestamp;

  _CacheEntry(this.result, this.timestamp);

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(minutes: 5);
}

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  HospitalSearchResult? _lastSearchResult;
  HospitalSearchResult? get lastSearchResult => _lastSearchResult;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<HospitalSearchResult>> _inFlightSearches = {};

  /// Clears the in-memory hospital search cache.
  void clearCache() {
    _cache.clear();
  }

  Future<HospitalSearchResult> searchHospitalsForLocation(
    SelectedLocation location, {
    Function(String status)? onProgress,
    bool forceRefresh = false,
  }) async {
    final double lat = location.latitude;
    final double lng = location.longitude;

    if (lat == 0.0 && lng == 0.0 && (location.cityName == null || location.cityName!.trim().isEmpty)) {
      throw ValidationException('Invalid GPS coordinates or city name provided for hospital search.');
    }

    final String locationKey =
        '${location.source.name}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}_${location.cityName ?? ""}';

    if (!forceRefresh && _cache.containsKey(locationKey)) {
      final entry = _cache[locationKey]!;
      if (!entry.isExpired) {
        debugPrint('[HOSPITAL SERVICE] Returning cached search result for key: $locationKey');
        _lastSearchResult = entry.result;
        return entry.result;
      } else {
        _cache.remove(locationKey);
      }
    }

    if (_inFlightSearches.containsKey(locationKey)) {
      debugPrint('[HOSPITAL SERVICE] Reusing in-flight search for key: $locationKey');
      return await _inFlightSearches[locationKey]!;
    }

    final Future<HospitalSearchResult> searchFuture = () async {
      try {
        HospitalSearchResult result = await _executeFastHospitalSearch(
          location: location,
          onProgress: onProgress,
        );

        if (result.hospitals.isNotEmpty) {
          _cache[locationKey] = _CacheEntry(result, DateTime.now());
        }
        _lastSearchResult = result;
        return result;
      } finally {
        _inFlightSearches.remove(locationKey);
      }
    }();

    _inFlightSearches[locationKey] = searchFuture;
    return await searchFuture;
  }

  /// Fast primary OpenStreetMap search with multi-radius failover.
  Future<HospitalSearchResult> _executeFastHospitalSearch({
    required SelectedLocation location,
    Function(String status)? onProgress,
  }) async {
    final double lat = location.latitude;
    final double lng = location.longitude;
    final Map<String, Hospital> deduplicatedMap = {};

    debugPrint('[HOSPITAL SERVICE] Starting search for coordinates ($lat, $lng), city: "${location.cityName}"');
    onProgress?.call('Fetching nearby healthcare facilities...');

    // 1. PRIMARY FAST SEARCH: Nominatim OpenStreetMap Search (< 1 second response)
    final nominatimHospitals = await _fetchHospitalsViaNominatim(
      latitude: lat,
      longitude: lng,
      city: location.cityName,
      onProgress: onProgress,
    );

    for (final h in nominatimHospitals) {
      deduplicatedMap[h.id] = h;
    }

    debugPrint('[HOSPITAL SERVICE] Nominatim returned ${nominatimHospitals.length} real hospitals');

    // 2. SECONDARY ENHANCEMENT: Query Overpass GET endpoint for additional node/way details
    if (lat != 0.0 && lng != 0.0) {
      try {
        final overpassHospitals = await _fetchHospitalsViaOverpassGet(
          latitude: lat,
          longitude: lng,
          radiusMeters: 5000,
        );
        for (final h in overpassHospitals) {
          if (!deduplicatedMap.containsKey(h.id)) {
            deduplicatedMap[h.id] = h;
          }
        }
        debugPrint('[HOSPITAL SERVICE] Overpass GET returned ${overpassHospitals.length} additional elements');
      } catch (e) {
        debugPrint('[HOSPITAL SERVICE] Overpass GET skipped/failed: $e');
      }
    }

    // Sort by distance
    final sortedList = deduplicatedMap.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final String searchLocationTitle = location.cityName != null && location.cityName!.isNotEmpty
        ? location.cityName!
        : 'your area';

    final String statusMsg = sortedList.isNotEmpty
        ? 'Found ${sortedList.length} hospital(s) near $searchLocationTitle.'
        : 'No hospitals found near $searchLocationTitle.';

    return HospitalSearchResult(
      hospitals: sortedList,
      maxRadiusMeters: 50000,
      city: location.cityName,
      statusMessage: statusMsg,
      location: location,
      searchSource: location.isGps ? 'gps' : 'city',
    );
  }

  /// Fetches real OpenStreetMap hospital nodes directly via Nominatim search engine.
  Future<List<Hospital>> _fetchHospitalsViaNominatim({
    double? latitude,
    double? longitude,
    String? city,
    Function(String status)? onProgress,
  }) async {
    try {
      String queryUrlStr;
      if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
        queryUrlStr =
            'https://nominatim.openstreetmap.org/search?q=hospitals+near+$latitude,$longitude&format=json&limit=30';
      } else if (city != null && city.trim().isNotEmpty) {
        queryUrlStr =
            'https://nominatim.openstreetmap.org/search?q=hospitals+in+${Uri.encodeComponent(city.trim())}&format=json&limit=30';
      } else {
        return [];
      }

      debugPrint('[HOSPITAL SERVICE] Nominatim GET query: $queryUrlStr');
      final queryUrl = Uri.parse(queryUrlStr);
      final response = await http
          .get(queryUrl, headers: {'User-Agent': 'MedGuardAI-App/1.0', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<Hospital> realHospitals = [];

        for (var i = 0; i < data.length; i++) {
          final item = data[i];
          final displayName = item['display_name'] ?? city ?? 'Hospital';
          final nameParts = displayName.split(',');
          final hospitalName = nameParts.first.trim();
          final address = nameParts.skip(1).take(3).join(',').trim();
          final itemLat = double.tryParse(item['lat']?.toString() ?? '') ?? 0.0;
          final itemLon = double.tryParse(item['lon']?.toString() ?? '') ?? 0.0;

          if (itemLat == 0.0 || itemLon == 0.0 || hospitalName.isEmpty) continue;

          double distKm = 1.0 + (i * 0.5);
          if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
            distKm = Geolocator.distanceBetween(latitude, longitude, itemLat, itemLon) / 1000.0;
          }

          final String osmId = item['place_id'] != null ? 'osm_city_${item['place_id']}' : 'osm_nom_$i';

          realHospitals.add(
            Hospital(
              id: osmId,
              name: hospitalName,
              address: address.isNotEmpty ? address : (city ?? 'Medical Facility'),
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
      } else {
        debugPrint('[HOSPITAL SERVICE] Nominatim HTTP status: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE ERROR] Nominatim request failed: $e');
      return [];
    }
  }

  /// Lightweight Overpass GET query for additional OpenStreetMap hospital nodes/ways.
  Future<List<Hospital>> _fetchHospitalsViaOverpassGet({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    final query =
        '[out:json][timeout:10];(node(around:$radiusMeters,$latitude,$longitude)[amenity~"hospital|clinic"];way(around:$radiusMeters,$latitude,$longitude)[amenity~"hospital|clinic"];);out center 30;';
    final urlStr = 'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
    
    try {
      final response = await http
          .get(Uri.parse(urlStr), headers: {'User-Agent': 'MedGuardAI-App/1.0', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List elements = data['elements'] ?? [];
        return _parseOsmElements(elements, latitude, longitude);
      }
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE] Overpass GET exception: $e');
    }
    return [];
  }

  List<Hospital> _parseOsmElements(List elements, double centerLat, double centerLng) {
    final List<Hospital> list = [];

    for (var i = 0; i < elements.length; i++) {
      final item = elements[i];
      final tags = item['tags'] ?? {};

      // Support node (lat/lon) as well as way/relation (center.lat / center.lon)
      final double? itemLat = (item['lat'] as num?)?.toDouble() ??
          (item['center']?['lat'] as num?)?.toDouble();
      final double? itemLon = (item['lon'] as num?)?.toDouble() ??
          (item['center']?['lon'] as num?)?.toDouble();

      if (itemLat == null || itemLon == null || itemLat == 0.0 || itemLon == 0.0) {
        continue;
      }

      final String? nameTag = tags['name'] ??
          tags['operator'] ??
          tags['name:en'] ??
          tags['official_name'] ??
          tags['brand'];

      if (nameTag == null || nameTag.trim().isEmpty) {
        continue;
      }

      final String name = nameTag.trim();
      final String street = tags['addr:street'] ??
          tags['addr:full'] ??
          tags['addr:suburb'] ??
          tags['addr:city'] ??
          tags['healthcare'] ??
          tags['amenity'] ??
          'Medical Facility';
      final String rawPhone = tags['phone'] ??
          tags['contact:phone'] ??
          tags['mobile'] ??
          tags['emergency:phone'] ??
          '';
      final String phone = rawPhone.trim();

      final double distanceMeters = Geolocator.distanceBetween(
        centerLat,
        centerLng,
        itemLat,
        itemLon,
      );
      final double distanceKm = distanceMeters / 1000.0;

      final String osmKey = item['type'] != null && item['id'] != null
          ? 'osm_${item['type']}_${item['id']}'
          : 'hospital_${name}_${itemLat.toStringAsFixed(3)}_${itemLon.toStringAsFixed(3)}';

      list.add(
        Hospital(
          id: osmKey,
          name: name,
          address: street,
          distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
          phone: phone,
          hasEmergencyServices:
              tags['emergency'] == 'yes' || tags['amenity'] == 'hospital',
          latitude: itemLat,
          longitude: itemLon,
          isDemoData: false,
        ),
      );
    }

    return list;
  }

  /// Progressively searches nearby real hospitals.
  Future<HospitalSearchResult> fetchNearbyHospitalsProgressive({
    double? latitude,
    double? longitude,
    SelectedLocation? location,
    Function(String status)? onProgress,
  }) async {
    final double lat = location?.latitude ?? latitude ?? 0.0;
    final double lng = location?.longitude ?? longitude ?? 0.0;

    final activeLoc = location ??
        SelectedLocation(
          latitude: lat,
          longitude: lng,
          cityName: 'Current Location',
          source: LocationSource.currentGps,
        );

    return await searchHospitalsForLocation(activeLoc, onProgress: onProgress);
  }

  /// Fetches nearby hospitals by coordinates or city search.
  Future<List<Hospital>> fetchNearbyHospitals({
    double? latitude,
    double? longitude,
    String? city,
    Function(String status)? onProgress,
  }) async {
    try {
      if (latitude != null && longitude != null && latitude != 0.0 && longitude != 0.0) {
        final loc = SelectedLocation(
          latitude: latitude,
          longitude: longitude,
          cityName: city ?? 'Current Location',
          source: city != null ? LocationSource.citySearch : LocationSource.currentGps,
        );
        final result = await searchHospitalsForLocation(loc, onProgress: onProgress);
        return result.hospitals;
      } else if (city != null && city.trim().isNotEmpty) {
        return await _fetchHospitalsViaNominatim(city: city, onProgress: onProgress);
      }
      return [];
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE ERROR] fetchNearbyHospitals failed: $e');
      return [];
    }
  }
}
