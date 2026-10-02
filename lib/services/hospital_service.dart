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
        HospitalSearchResult result = await _executeProgressiveSearch(
          location: location,
          onProgress: onProgress,
        );

        if (result.hospitals.isEmpty && location.cityName != null && location.cityName!.trim().isNotEmpty) {
          debugPrint('[HOSPITAL SERVICE] Progressive search returned 0. Trying Nominatim city search for ${location.cityName}...');
          final cityHospitals = await _fetchHospitalsViaNominatim(
            latitude: lat,
            longitude: lng,
            city: location.cityName,
            onProgress: onProgress,
          );
          if (cityHospitals.isNotEmpty) {
            result = HospitalSearchResult(
              hospitals: cityHospitals,
              maxRadiusMeters: 50000,
              city: location.cityName,
              statusMessage: 'Found ${cityHospitals.length} hospital(s) near ${location.cityName}.',
              location: location,
              searchSource: location.isGps ? 'gps' : 'city',
            );
          }
        }

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

  /// Progressively searches nearby real hospitals from user's coordinates or selected location.
  /// Radii steps: 5 km, 10 km, 25 km, 50 km.
  /// Stops as soon as valid hospitals are found or 50 km max radius is reached.
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

  Future<HospitalSearchResult> _executeProgressiveSearch({
    required SelectedLocation location,
    Function(String status)? onProgress,
  }) async {
    final double lat = location.latitude;
    final double lng = location.longitude;

    final Map<String, Hospital> deduplicatedMap = {};
    final List<int> progressiveRadii = [5000, 10000, 25000, 50000];
    int currentRadius = 5000;

    final List<String> overpassEndpoints = [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    ];

    bool anyEndpointResponded = false;

    for (final radius in progressiveRadii) {
      currentRadius = radius;
      final radiusKm = radius ~/ 1000;
      onProgress?.call('Searching hospitals within $radiusKm km...');
      debugPrint('[HOSPITAL SERVICE] Searching radius: ${radiusKm}km around ($lat, $lng)');

      final overpassQuery =
          '[out:json][timeout:25];(node(around:$radius,$lat,$lng)[amenity~"hospital|clinic|doctors"];way(around:$radius,$lat,$lng)[amenity~"hospital|clinic|doctors"];relation(around:$radius,$lat,$lng)[amenity~"hospital|clinic|doctors"];);out center 50;';

      bool radiusSuccess = false;
      for (final endpoint in overpassEndpoints) {
        if (radiusSuccess) break;
        try {
          debugPrint('[HOSPITAL SERVICE] Requesting Overpass endpoint: $endpoint for ${radius}m');
          final response = await http.post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'data=${Uri.encodeComponent(overpassQuery)}',
          ).timeout(const Duration(seconds: 20));

          if (response.statusCode == 200) {
            anyEndpointResponded = true;
            final data = json.decode(response.body);
            final List elements = data['elements'] ?? [];
            debugPrint('[HOSPITAL SERVICE] Endpoint $endpoint returned ${elements.length} OSM elements');

            final parsedHospitals = _parseOsmElements(elements, lat, lng);
            for (final h in parsedHospitals) {
              deduplicatedMap[h.id] = h;
            }
            radiusSuccess = true;
          } else {
            debugPrint('[HOSPITAL SERVICE] Overpass HTTP status ${response.statusCode} from $endpoint');
          }
        } catch (e) {
          debugPrint('[HOSPITAL SERVICE] Overpass endpoint error ($endpoint at ${radius}m): $e');
        }
      }

      // If Overpass endpoints failed/timed out on 5000m, attempt Nominatim fallback
      if (!radiusSuccess && !anyEndpointResponded && deduplicatedMap.isEmpty) {
        debugPrint('[HOSPITAL SERVICE] Overpass endpoints unresponsive. Falling back to Nominatim healthcare search...');
        onProgress?.call('Fetching nearby healthcare data...');
        final fallbackHospitals = await _fetchHospitalsViaNominatim(
          latitude: lat,
          longitude: lng,
          city: location.cityName,
          onProgress: onProgress,
        );
        for (final h in fallbackHospitals) {
          deduplicatedMap[h.id] = h;
        }
        if (deduplicatedMap.isNotEmpty) {
          break; // Stop progressive search if Nominatim returned real hospitals
        }
      }

      final sortedList = deduplicatedMap.values.toList()
        ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

      // EARLY EXIT: If 1 or more valid hospitals found, stop progressive expansion!
      if (sortedList.isNotEmpty || radius == 50000) {
        debugPrint('[HOSPITAL SERVICE] Search completed at radius ${currentRadius}m with ${sortedList.length} hospitals');
        return HospitalSearchResult(
          hospitals: sortedList,
          maxRadiusMeters: currentRadius,
          statusMessage: sortedList.isNotEmpty
              ? 'Found ${sortedList.length} hospital(s) within ${currentRadius ~/ 1000} km.'
              : 'No nearby hospitals found within 50 km.',
          location: location,
          searchSource: location.isGps ? 'gps' : 'city',
        );
      }
    }

    final sortedList = deduplicatedMap.values.toList()
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    return HospitalSearchResult(
      hospitals: sortedList,
      maxRadiusMeters: currentRadius,
      statusMessage: sortedList.isNotEmpty
          ? 'Found ${sortedList.length} hospital(s) within ${currentRadius ~/ 1000} km.'
          : 'No nearby hospitals found.',
      location: location,
      searchSource: location.isGps ? 'gps' : 'city',
    );
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
        // Ignore nameless OSM entries to keep result list high quality
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
            'https://nominatim.openstreetmap.org/search?q=hospital&format=json&lat=$latitude&lon=$longitude&bounded=1&limit=25';
      } else if (city != null && city.trim().isNotEmpty) {
        queryUrlStr =
            'https://nominatim.openstreetmap.org/search?q=hospitals+in+${Uri.encodeComponent(city.trim())}&format=json&limit=25';
      } else {
        return [];
      }

      debugPrint('[HOSPITAL SERVICE] Nominatim GET query: $queryUrlStr');
      final queryUrl = Uri.parse(queryUrlStr);
      final response = await http
          .get(queryUrl, headers: {'User-Agent': 'MedGuardAI-App/1.0'})
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final List<Hospital> realHospitals = [];

        for (var i = 0; i < data.length; i++) {
          final item = data[i];
          final displayName = item['display_name'] ?? city ?? 'Hospital';
          final nameParts = displayName.split(',');
          final hospitalName = nameParts.first.trim();
          final address = nameParts.skip(1).take(2).join(',').trim();
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
      }
      return [];
    } catch (e) {
      debugPrint('[HOSPITAL SERVICE ERROR] Nominatim fallback failed: $e');
      return [];
    }
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
      throw NetworkException('Unable to search nearby hospitals. Please verify your connection.');
    }
  }
}
