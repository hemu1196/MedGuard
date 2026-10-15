import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../core/api/api_client.dart';
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

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(minutes: 10);
}

class HospitalService {
  static final HospitalService _instance = HospitalService._internal();
  factory HospitalService() => _instance;
  HospitalService._internal();

  HospitalSearchResult? _lastSearchResult;
  HospitalSearchResult? get lastSearchResult => _lastSearchResult;

  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<HospitalSearchResult>> _inFlightSearches = {};

  /// Overpass mirror endpoints for resilient fallback
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Clears in-memory cache
  void clearCache() {
    _cache.clear();
  }

  /// Searches hospitals for a given SelectedLocation using progressive radius discovery
  Future<HospitalSearchResult> searchHospitalsForLocation(
    SelectedLocation location, {
    Function(String status)? onProgress,
    bool forceRefresh = false,
  }) async {
    final double lat = location.latitude;
    final double lng = location.longitude;
    final String? city = location.cityName;

    if (lat == 0.0 && lng == 0.0 && (city == null || city.trim().isEmpty)) {
      throw ValidationException('Valid GPS coordinates or city name are required to search hospitals.');
    }

    final String locationKey =
        '${location.source.name}_${lat.toStringAsFixed(3)}_${lng.toStringAsFixed(3)}_${city ?? ""}';

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
        HospitalSearchResult result = await _executeProgressiveHealthcareSearch(
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

  /// Progressive healthcare search: 5km -> 10km -> 20km -> 50km
  Future<HospitalSearchResult> _executeProgressiveHealthcareSearch({
    required SelectedLocation location,
    Function(String status)? onProgress,
  }) async {
    final double lat = location.latitude;
    final double lng = location.longitude;
    final String? city = location.cityName;

    final List<int> progressiveRadii = [5000, 10000, 20000, 50000];
    final Map<String, Hospital> deduplicatedMap = {};
    int lastUsedRadius = 5000;

    for (final radius in progressiveRadii) {
      lastUsedRadius = radius;
      final radiusKm = radius ~/ 1000;

      onProgress?.call('Searching hospitals within ${radiusKm}km...');
      debugPrint('[HOSPITAL SERVICE] Searching healthcare for ($lat, $lng), city: "$city", radius: ${radiusKm}km');

      // 1. TIER 1: Try Render backend proxy endpoint
      try {
        final backendHospitals = await _fetchViaBackend(
          lat: lat,
          lng: lng,
          radiusMeters: radius,
          city: city,
        );

        if (backendHospitals.isNotEmpty) {
          for (final h in backendHospitals) {
            deduplicatedMap[h.id] = h;
          }
          debugPrint('[HOSPITAL SERVICE] Backend returned ${backendHospitals.length} facilities at ${radiusKm}km');
          // If we found sufficient facilities, stop expanding
          if (deduplicatedMap.length >= 4 || radius >= 20000) {
            break;
          }
        }
      } catch (e) {
        debugPrint('[HOSPITAL SERVICE] Backend proxy fetch note: $e');
      }

      // 2. TIER 2: Direct Nominatim Spatial Search using Viewbox Bounding Box
      if (deduplicatedMap.length < 4 && lat != 0.0 && lng != 0.0) {
        try {
          final nominatimHospitals = await _fetchViaNominatimSpatial(
            latitude: lat,
            longitude: lng,
            radiusMeters: radius,
          );

          for (final h in nominatimHospitals) {
            if (!deduplicatedMap.containsKey(h.id)) {
              deduplicatedMap[h.id] = h;
            } else {
              _enrichExistingHospital(deduplicatedMap[h.id]!, h, deduplicatedMap);
            }
          }
          debugPrint('[HOSPITAL SERVICE] Nominatim spatial returned ${nominatimHospitals.length} places (Total unique: ${deduplicatedMap.length})');
        } catch (e) {
          debugPrint('[HOSPITAL SERVICE] Nominatim spatial query note: $e');
        }
      }

      // 3. TIER 3: Direct Overpass API with corrected QL syntax
      if (deduplicatedMap.length < 3 && lat != 0.0 && lng != 0.0) {
        try {
          final overpassHospitals = await _fetchViaOverpass(
            latitude: lat,
            longitude: lng,
            radiusMeters: radius,
          );

          for (final h in overpassHospitals) {
            if (!deduplicatedMap.containsKey(h.id)) {
              deduplicatedMap[h.id] = h;
            } else {
              _enrichExistingHospital(deduplicatedMap[h.id]!, h, deduplicatedMap);
            }
          }
          debugPrint('[HOSPITAL SERVICE] Overpass returned ${overpassHospitals.length} places');
        } catch (e) {
          debugPrint('[HOSPITAL SERVICE] Overpass query note: $e');
        }
      }

      // 4. City search fallback if coordinates were not precise or if search originated from city name
      if (deduplicatedMap.isEmpty && city != null && city.trim().isNotEmpty) {
        try {
          final cityHospitals = await _fetchViaNominatimCity(city: city);
          for (final h in cityHospitals) {
            if (!deduplicatedMap.containsKey(h.id)) {
              deduplicatedMap[h.id] = h;
            }
          }
        } catch (e) {
          debugPrint('[HOSPITAL SERVICE] City search note: $e');
        }
      }

      // If we have found 4 or more hospitals, no need to expand further
      if (deduplicatedMap.length >= 4) {
        break;
      }
    }

    // Sort: Verified emergency first, then by distance
    final sortedList = deduplicatedMap.values.toList()
      ..sort((a, b) {
        if (a.emergencyServiceVerified != b.emergencyServiceVerified) {
          return a.emergencyServiceVerified ? -1 : 1;
        }
        return a.distanceMeters.compareTo(b.distanceMeters);
      });

    final String searchLocationTitle = location.cityName != null && location.cityName!.isNotEmpty
        ? location.cityName!
        : 'your current area';

    final String statusMsg = sortedList.isNotEmpty
        ? 'Found ${sortedList.length} healthcare facility(ies) within ${lastUsedRadius ~/ 1000}km of $searchLocationTitle.'
        : 'No healthcare facilities found within ${lastUsedRadius ~/ 1000}km of $searchLocationTitle.';

    return HospitalSearchResult(
      hospitals: sortedList,
      maxRadiusMeters: lastUsedRadius,
      city: location.cityName,
      statusMessage: statusMsg,
      location: location,
      searchSource: location.isGps ? 'gps' : 'city',
    );
  }

  void _enrichExistingHospital(Hospital existing, Hospital h, Map<String, Hospital> map) {
    if (!existing.hasValidPhone && h.hasValidPhone) {
      map[existing.id] = Hospital(
        id: existing.id,
        source: existing.source,
        sourcePlaceId: existing.sourcePlaceId,
        name: existing.name,
        category: existing.category,
        latitude: existing.latitude,
        longitude: existing.longitude,
        address: existing.address,
        phoneNumber: h.phoneNumber,
        website: existing.website.isNotEmpty ? existing.website : h.website,
        openingHours: existing.openingHours.isNotEmpty ? existing.openingHours : h.openingHours,
        emergencyServiceVerified: existing.emergencyServiceVerified || h.emergencyServiceVerified,
        emergencyVerificationSource: existing.emergencyServiceVerified
            ? existing.emergencyVerificationSource
            : h.emergencyVerificationSource,
        distanceMeters: existing.distanceMeters,
        isDemoData: false,
      );
    }
  }

  /// Fetches hospitals via MEDGUARD backend proxy `/api/hospitals/nearby`
  Future<List<Hospital>> _fetchViaBackend({
    required double lat,
    required double lng,
    required int radiusMeters,
    String? city,
  }) async {
    final queryParams = <String, String>{
      'radius': radiusMeters.toString(),
    };
    if (lat != 0.0 && lng != 0.0) {
      queryParams['lat'] = lat.toString();
      queryParams['lng'] = lng.toString();
    }
    if (city != null && city.trim().isNotEmpty) {
      queryParams['city'] = city.trim();
    }

    final path = '/hospitals/nearby?${Uri(queryParameters: queryParams).query}';
    final response = await ApiClient().get(path).timeout(const Duration(seconds: 7));

    if (response['success'] == true) {
      final List rawList = response['hospitals'] as List? ?? [];
      return rawList.map((item) => Hospital.fromMap(Map<String, dynamic>.from(item))).toList();
    }
    return [];
  }

  /// Fetches healthcare facilities directly via Nominatim with spatial viewbox
  Future<List<Hospital>> _fetchViaNominatimSpatial({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    // 1 deg latitude ~= 111.0 km, 1 deg longitude ~= 111.0 * cos(lat) km
    final double latDelta = radiusMeters / 111000.0;
    final double cosLat = math.cos(latitude * math.pi / 180.0);
    final double lngDelta = radiusMeters / (111000.0 * (cosLat.abs() > 0.05 ? cosLat.abs() : 0.05));

    final String minLon = (longitude - lngDelta).toStringAsFixed(5);
    final String maxLon = (longitude + lngDelta).toStringAsFixed(5);
    final String minLat = (latitude - latDelta).toStringAsFixed(5);
    final String maxLat = (latitude + latDelta).toStringAsFixed(5);

    final String viewbox = '$minLon,$maxLat,$maxLon,$minLat';

    final String urlStr =
        'https://nominatim.openstreetmap.org/search?format=json&amenity=hospital&viewbox=$viewbox&bounded=1&limit=25&addressdetails=1&extratags=1';

    final response = await http
        .get(Uri.parse(urlStr), headers: {
          'User-Agent': 'MEDGUARD-Healthcare-Assistant/2.0 (contact@medguard.app)',
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      final List<Hospital> results = [];
      for (final item in data) {
        final h = _parseNominatimItem(item, latitude, longitude);
        if (h != null) results.add(h);
      }
      return results;
    }
    return [];
  }

  /// Fetches healthcare facilities by city name via Nominatim
  Future<List<Hospital>> _fetchViaNominatimCity({
    required String city,
  }) async {
    final cleanCity = city.trim();
    if (cleanCity.isEmpty) return [];

    final String urlStr =
        'https://nominatim.openstreetmap.org/search?format=json&q=hospital+${Uri.encodeComponent(cleanCity)}&limit=25&addressdetails=1&extratags=1';

    final response = await http
        .get(Uri.parse(urlStr), headers: {
          'User-Agent': 'MEDGUARD-Healthcare-Assistant/2.0 (contact@medguard.app)',
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      final List<Hospital> results = [];
      for (final item in data) {
        final h = _parseNominatimItem(item, 0.0, 0.0);
        if (h != null) results.add(h);
      }
      return results;
    }
    return [];
  }

  /// Parses Nominatim response item into normalized Hospital
  Hospital? _parseNominatimItem(Map item, double centerLat, double centerLng) {
    final double? itemLat = double.tryParse(item['lat']?.toString() ?? '');
    final double? itemLon = double.tryParse(item['lon']?.toString() ?? '');

    if (itemLat == null || itemLon == null || (itemLat == 0.0 && itemLon == 0.0)) {
      return null;
    }

    final Map extraTags = item['extratags'] is Map ? item['extratags'] as Map : {};
    final Map addressObj = item['address'] is Map ? item['address'] as Map : {};

    // Name determination
    String facilityName = item['name']?.toString() ??
        addressObj['amenity']?.toString() ??
        addressObj['hospital']?.toString() ??
        addressObj['clinic']?.toString() ??
        '';

    if (facilityName.isEmpty && item['display_name'] != null) {
      facilityName = item['display_name'].toString().split(',').first.trim();
    }
    if (facilityName.isEmpty) {
      facilityName = 'Healthcare Facility';
    }

    // Address
    final List<String> addressParts = [];
    if (addressObj['house_number'] != null) addressParts.add(addressObj['house_number'].toString());
    if (addressObj['road'] != null) addressParts.add(addressObj['road'].toString());
    if (addressObj['suburb'] != null || addressObj['neighbourhood'] != null) {
      addressParts.add((addressObj['suburb'] ?? addressObj['neighbourhood']).toString());
    }
    if (addressObj['city'] != null || addressObj['town'] != null || addressObj['village'] != null) {
      addressParts.add((addressObj['city'] ?? addressObj['town'] ?? addressObj['village']).toString());
    }

    String address = addressParts.join(', ').trim();
    if (address.isEmpty && item['display_name'] != null) {
      final parts = item['display_name'].toString().split(',');
      address = parts.skip(1).take(3).join(', ').trim();
    }
    if (address.isEmpty) {
      address = 'Address not specified';
    }

    final rawPhone = extraTags['phone'] ??
        extraTags['contact:phone'] ??
        extraTags['emergency:phone'] ??
        extraTags['mobile'] ??
        '';
    final normalizedPhone = _cleanPhoneNumber(rawPhone.toString());

    final bool isEmergencyVerified = extraTags['emergency'] == 'yes' ||
        extraTags['emergency:service'] == 'yes' ||
        extraTags['healthcare:emergency'] == 'yes';

    final category = _determineCategory(
      {
        'amenity': item['type'] ?? item['class'] ?? '',
        'healthcare': extraTags['healthcare'] ?? '',
        'emergency': extraTags['emergency'] ?? '',
      },
      facilityName,
    );

    double distanceMeters = 0.0;
    if (centerLat != 0.0 && centerLng != 0.0) {
      distanceMeters = Geolocator.distanceBetween(centerLat, centerLng, itemLat, itemLon);
    }

    final String id = 'osm_${item['osm_type'] ?? 'node'}_${item['osm_id'] ?? item['place_id']}';

    return Hospital(
      id: id,
      source: 'openstreetmap_nominatim',
      sourcePlaceId: item['place_id']?.toString() ?? '',
      name: facilityName,
      category: category,
      latitude: itemLat,
      longitude: itemLon,
      address: address,
      phoneNumber: normalizedPhone,
      website: extraTags['website']?.toString() ?? '',
      openingHours: extraTags['opening_hours']?.toString() ?? '',
      emergencyServiceVerified: isEmergencyVerified,
      emergencyVerificationSource: isEmergencyVerified ? 'OpenStreetMap Verified' : 'unverified',
      distanceMeters: distanceMeters,
      isDemoData: false,
    );
  }

  /// Fetches rich OpenStreetMap healthcare nodes, ways & relations via Overpass API
  Future<List<Hospital>> _fetchViaOverpass({
    required double latitude,
    required double longitude,
    required int radiusMeters,
  }) async {
    // Correct Overpass QL syntax with limit: [out:json][timeout:8];(...);out center 40;
    final query =
        '[out:json][timeout:8];(node(around:$radiusMeters,$latitude,$longitude)[amenity~"hospital|clinic"];way(around:$radiusMeters,$latitude,$longitude)[amenity~"hospital|clinic"];relation(around:$radiusMeters,$latitude,$longitude)[amenity~"hospital|clinic"];);out center 40;';

    for (final endpoint in _overpassEndpoints) {
      try {
        final urlStr = '$endpoint?data=${Uri.encodeComponent(query)}';
        final response = await http
            .get(Uri.parse(urlStr), headers: {
              'User-Agent': 'MEDGUARD-Healthcare-Assistant/2.0 (contact@medguard.app)',
              'Accept': 'application/json',
            })
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List elements = data['elements'] ?? [];
          final list = _parseOsmElements(elements, latitude, longitude);
          if (list.isNotEmpty) {
            return list;
          }
        }
      } catch (e) {
        debugPrint('[HOSPITAL SERVICE] Overpass mirror $endpoint error: $e');
      }
    }
    return [];
  }

  /// Parses OpenStreetMap elements into normalized Hospital records
  List<Hospital> _parseOsmElements(List elements, double centerLat, double centerLng) {
    final List<Hospital> list = [];

    for (var i = 0; i < elements.length; i++) {
      final item = elements[i];
      final tags = item['tags'] ?? {};

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
      final HealthcareCategory category = _determineCategory(tags, name);

      final bool emergencyVerified = tags['emergency'] == 'yes' ||
          tags['emergency:service'] == 'yes' ||
          tags['healthcare:emergency'] == 'yes';

      final String emergencySource = emergencyVerified
          ? 'OpenStreetMap Verified Emergency'
          : 'unverified';

      final List<String> addressParts = [];
      if (tags['addr:housenumber'] != null) addressParts.add(tags['addr:housenumber'].toString());
      if (tags['addr:street'] != null) addressParts.add(tags['addr:street'].toString());
      if (tags['addr:suburb'] != null) addressParts.add(tags['addr:suburb'].toString());
      if (tags['addr:city'] != null) addressParts.add(tags['addr:city'].toString());

      String address = addressParts.join(', ').trim();
      if (address.isEmpty) {
        address = tags['addr:full'] ?? tags['note'] ?? category.displayName;
      }

      final String rawPhone = tags['phone'] ??
          tags['contact:phone'] ??
          tags['emergency:phone'] ??
          tags['mobile'] ??
          tags['contact:mobile'] ??
          '';
      final String normalizedPhone = _cleanPhoneNumber(rawPhone);

      final String hours = tags['opening_hours']?.toString() ?? '';
      final String website = tags['website']?.toString() ??
          tags['contact:website']?.toString() ??
          '';

      final double distanceMeters = (centerLat != 0.0 && centerLng != 0.0)
          ? Geolocator.distanceBetween(centerLat, centerLng, itemLat, itemLon)
          : 0.0;

      final String osmKey = item['type'] != null && item['id'] != null
          ? 'osm_${item['type']}_${item['id']}'
          : 'osm_item_${i}_${itemLat.toStringAsFixed(4)}';

      list.add(
        Hospital(
          id: osmKey,
          source: 'openstreetmap_overpass',
          sourcePlaceId: item['id']?.toString() ?? '',
          name: name,
          category: category,
          latitude: itemLat,
          longitude: itemLon,
          address: address,
          phoneNumber: normalizedPhone,
          website: website,
          openingHours: hours,
          emergencyServiceVerified: emergencyVerified,
          emergencyVerificationSource: emergencySource,
          distanceMeters: distanceMeters,
          isDemoData: false,
        ),
      );
    }

    return list;
  }

  /// Classifies facility into standard HealthcareCategory based on OSM tags
  HealthcareCategory _determineCategory(Map tags, String name) {
    final amenity = (tags['amenity'] ?? '').toString().toLowerCase();
    final healthcare = (tags['healthcare'] ?? '').toString().toLowerCase();
    final emergency = (tags['emergency'] ?? '').toString().toLowerCase();
    final nameLower = name.toLowerCase();

    if (emergency == 'yes' ||
        nameLower.contains('trauma') ||
        nameLower.contains('casualty') ||
        nameLower.contains('emergency center') ||
        nameLower.contains('emergency hospital')) {
      return HealthcareCategory.emergencyDepartment;
    }
    if (amenity == 'pharmacy' ||
        healthcare == 'pharmacy' ||
        nameLower.contains('pharmacy') ||
        nameLower.contains('medical hall') ||
        nameLower.contains('chemist')) {
      return HealthcareCategory.pharmacy;
    }
    if (healthcare == 'centre' ||
        nameLower.contains('primary health') ||
        nameLower.contains('phc') ||
        nameLower.contains('community health centre') ||
        nameLower.contains('dispensary')) {
      return HealthcareCategory.primaryHealthCentre;
    }
    if (amenity == 'clinic' ||
        healthcare == 'clinic' ||
        amenity == 'doctors' ||
        healthcare == 'doctor' ||
        nameLower.contains('clinic') ||
        nameLower.contains('polyclinic')) {
      return HealthcareCategory.clinic;
    }
    if (amenity == 'hospital' || healthcare == 'hospital' || nameLower.contains('hospital')) {
      return HealthcareCategory.hospital;
    }
    return HealthcareCategory.otherHealthcareFacility;
  }

  /// Sanitizes phone numbers by extracting first valid contact number
  String _cleanPhoneNumber(String raw) {
    if (raw.trim().isEmpty) return '';
    final parts = raw.split(RegExp(r'[;,/|]'));
    for (final p in parts) {
      final trimmed = p.trim();
      final digitCount = trimmed.replaceAll(RegExp(r'[^\d]'), '').length;
      if (digitCount >= 6) {
        return trimmed;
      }
    }
    return '';
  }

  /// Progressively searches nearby real hospitals
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

  /// Fetches nearby hospitals by coordinates or city search
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
        final loc = SelectedLocation(
          latitude: 0.0,
          longitude: 0.0,
          cityName: city.trim(),
          source: LocationSource.citySearch,
        );
        final result = await searchHospitalsForLocation(loc, onProgress: onProgress);
        return result.hospitals;
      }
      return [];
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE ERROR] fetchNearbyHospitals failed: $e');
      return [];
    }
  }
}
