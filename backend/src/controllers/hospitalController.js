const https = require('https');
const http = require('http');

// In-memory cache with TTL (15 minutes)
const searchCache = new Map();
const CACHE_TTL_MS = 15 * 60 * 1000;

function getCacheKey(lat, lng, radius, city) {
  if (city && (!lat || !lng)) {
    return `city_${city.toLowerCase().trim()}_${radius}`;
  }
  return `geo_${Number(lat).toFixed(2)}_${Number(lng).toFixed(2)}_${radius}_${(city || '').toLowerCase().trim()}`;
}

function cleanExpiredCache() {
  const now = Date.now();
  for (const [key, entry] of searchCache.entries()) {
    if (now - entry.timestamp > CACHE_TTL_MS) {
      searchCache.delete(key);
    }
  }
}

// Calculate distance in meters using Haversine formula
function calculateDistanceMeters(lat1, lon1, lat2, lon2) {
  const R = 6371e3; // Earth radius in meters
  const phi1 = (lat1 * Math.PI) / 180;
  const phi2 = (lat2 * Math.PI) / 180;
  const deltaPhi = ((lat2 - lat1) * Math.PI) / 180;
  const deltaLambda = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(deltaPhi / 2) * Math.sin(deltaPhi / 2) +
    Math.cos(phi1) * Math.cos(phi2) * Math.sin(deltaLambda / 2) * Math.sin(deltaLambda / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return Math.round(R * c);
}

// Helper to make HTTPS requests with timeout and user agent
function fetchJson(urlStr, timeoutMs = 8000) {
  return new Promise((resolve, reject) => {
    const url = new URL(urlStr);
    const client = url.protocol === 'https:' ? https : http;

    const req = client.get(
      url,
      {
        headers: {
          'User-Agent': 'MEDGUARD-Healthcare-Assistant/2.0 (contact@medguard.app)',
          Accept: 'application/json',
        },
        timeout: timeoutMs,
      },
      (res) => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          res.resume(); // Consume response data to free memory
          return reject(new Error(`HTTP ${res.statusCode} from ${url.hostname}`));
        }

        let rawData = '';
        res.setEncoding('utf8');
        res.on('data', (chunk) => (rawData += chunk));
        res.on('end', () => {
          try {
            const parsed = JSON.parse(rawData);
            resolve(parsed);
          } catch (e) {
            reject(new Error(`JSON parse error from ${url.hostname}: ${e.message}`));
          }
        });
      }
    );

    req.on('timeout', () => {
      req.destroy();
      reject(new Error(`Request timeout (${timeoutMs}ms) to ${url.hostname}`));
    });

    req.on('error', (err) => {
      reject(err);
    });
  });
}

function cleanPhoneNumber(raw) {
  if (!raw || typeof raw !== 'string') return '';
  const parts = raw.split(/[;,/|]/);
  for (const p of parts) {
    const trimmed = p.trim();
    const digitCount = (trimmed.match(/\d/g) || []).length;
    if (digitCount >= 6) {
      return trimmed;
    }
  }
  return '';
}

function determineCategory(item, extraTags, name) {
  const amenity = String(item.type || item.class || '').toLowerCase();
  const healthcare = String(extraTags.healthcare || '').toLowerCase();
  const emergency = String(extraTags.emergency || '').toLowerCase();
  const nameLower = String(name || '').toLowerCase();

  if (
    emergency === 'yes' ||
    nameLower.includes('trauma') ||
    nameLower.includes('casualty') ||
    nameLower.includes('emergency')
  ) {
    return 'emergencyDepartment';
  }
  if (
    amenity === 'pharmacy' ||
    healthcare === 'pharmacy' ||
    nameLower.includes('pharmacy') ||
    nameLower.includes('chemist') ||
    nameLower.includes('drugstore')
  ) {
    return 'pharmacy';
  }
  if (
    healthcare === 'centre' ||
    nameLower.includes('primary health') ||
    nameLower.includes('phc') ||
    nameLower.includes('dispensary')
  ) {
    return 'primaryHealthCentre';
  }
  if (
    amenity === 'clinic' ||
    healthcare === 'clinic' ||
    amenity === 'doctors' ||
    healthcare === 'doctor' ||
    nameLower.includes('clinic') ||
    nameLower.includes('polyclinic')
  ) {
    return 'clinic';
  }
  if (amenity === 'hospital' || healthcare === 'hospital' || nameLower.includes('hospital')) {
    return 'hospital';
  }
  return 'otherHealthcareFacility';
}

function parseNominatimItem(item, searchLat, searchLng) {
  const extraTags = (item.extratags && typeof item.extratags === 'object') ? item.extratags : {};
  const addressObj = (item.address && typeof item.address === 'object') ? item.address : {};

  const itemLat = parseFloat(item.lat);
  const itemLon = parseFloat(item.lon);
  if (isNaN(itemLat) || isNaN(itemLon) || (itemLat === 0 && itemLon === 0)) {
    return null;
  }

  // Determine Facility Name
  let facilityName = item.name || addressObj.amenity || addressObj.hospital || addressObj.clinic;
  if (!facilityName && item.display_name) {
    facilityName = item.display_name.split(',')[0].trim();
  }
  if (!facilityName || facilityName.trim().length === 0) {
    facilityName = 'Healthcare Facility';
  }
  facilityName = facilityName.trim();

  // Address
  const addressParts = [];
  if (addressObj.house_number) addressParts.push(addressObj.house_number);
  if (addressObj.road) addressParts.push(addressObj.road);
  if (addressObj.suburb || addressObj.neighbourhood) addressParts.push(addressObj.suburb || addressObj.neighbourhood);
  if (addressObj.city || addressObj.town || addressObj.village) addressParts.push(addressObj.city || addressObj.town || addressObj.village);

  let address = addressParts.join(', ');
  if (!address && item.display_name) {
    address = item.display_name.split(',').slice(1, 4).join(', ').trim();
  }
  if (!address) {
    address = 'Address not specified';
  }

  const phone = cleanPhoneNumber(
    extraTags.phone ||
    extraTags['contact:phone'] ||
    extraTags['emergency:phone'] ||
    extraTags.mobile ||
    ''
  );

  const website = String(extraTags.website || extraTags['contact:website'] || '').trim();
  const openingHours = String(extraTags.opening_hours || '').trim();

  const isEmergencyVerified =
    extraTags.emergency === 'yes' ||
    extraTags['emergency:service'] === 'yes' ||
    extraTags['healthcare:emergency'] === 'yes';

  const category = determineCategory(item, extraTags, facilityName);

  const distanceMeters = (searchLat && searchLng)
    ? calculateDistanceMeters(searchLat, searchLng, itemLat, itemLon)
    : 0;

  return {
    id: `osm_${item.osm_type || 'node'}_${item.osm_id || item.place_id}`,
    source: 'openstreetmap_nominatim',
    sourcePlaceId: String(item.place_id || item.osm_id || ''),
    name: facilityName,
    category,
    latitude: itemLat,
    longitude: itemLon,
    address,
    phoneNumber: phone,
    website,
    openingHours,
    emergencyServiceVerified: isEmergencyVerified,
    emergencyVerificationSource: isEmergencyVerified ? 'OpenStreetMap Verified' : 'unverified',
    distanceMeters,
    lastFetchedAt: new Date().toISOString(),
    isDemoData: false,
  };
}

/**
 * Controller to search nearby hospitals by coordinates or city
 */
exports.getNearbyHospitals = async (req, res) => {
  cleanExpiredCache();

  try {
    let lat = parseFloat(req.query.lat || req.query.latitude);
    let lng = parseFloat(req.query.lng || req.query.lon || req.query.longitude);
    let radius = parseInt(req.query.radius || '6000', 10);
    const city = req.query.city ? String(req.query.city).trim() : null;

    if (isNaN(radius) || radius <= 0) radius = 6000;
    if (radius > 50000) radius = 50000;

    // If city is provided without coordinates, geocode city first
    if ((isNaN(lat) || isNaN(lng) || (lat === 0 && lng === 0)) && city) {
      const geoUrl = `https://nominatim.openstreetmap.org/search?q=${encodeURIComponent(city)}&format=json&limit=1`;
      try {
        const geoResults = await fetchJson(geoUrl, 6000);
        if (Array.isArray(geoResults) && geoResults.length > 0) {
          lat = parseFloat(geoResults[0].lat);
          lng = parseFloat(geoResults[0].lon);
        }
      } catch (err) {
        console.warn(`[HOSPITAL CONTROLLER] City geocode failed for "${city}":`, err.message);
      }
    }

    if (isNaN(lat) || isNaN(lng) || (lat === 0 && lng === 0)) {
      return res.status(400).json({
        success: false,
        message: 'Valid coordinates (lat, lng) or a verifiable city name are required.',
      });
    }

    // Check cache
    const cacheKey = getCacheKey(lat, lng, radius, city);
    const cached = searchCache.get(cacheKey);
    if (cached && Date.now() - cached.timestamp < CACHE_TTL_MS) {
      return res.json({
        success: true,
        count: cached.data.length,
        radiusMeters: radius,
        cached: true,
        location: {
          latitude: lat,
          longitude: lng,
          cityName: city || null,
        },
        hospitals: cached.data,
      });
    }

    // Calculate bounding box viewbox for Nominatim
    // 1 deg latitude ~= 111.0 km, 1 deg longitude ~= 111.0 * cos(lat) km
    const latDelta = radius / 111000;
    const cosLat = Math.cos((lat * Math.PI) / 180);
    const lngDelta = radius / (111000 * (cosLat > 0.05 ? cosLat : 0.05));

    const minLon = (lng - lngDelta).toFixed(5);
    const maxLon = (lng + lngDelta).toFixed(5);
    const minLat = (lat - latDelta).toFixed(5);
    const maxLat = (lat + latDelta).toFixed(5);

    // viewbox=<left>,<top>,<right>,<bottom> -> minLon,maxLat,maxLon,minLat
    const viewbox = `${minLon},${maxLat},${maxLon},${minLat}`;

    const deduplicated = new Map();

    // 1. Search hospitals with viewbox
    const hospitalSearchUrl = `https://nominatim.openstreetmap.org/search?format=json&amenity=hospital&viewbox=${viewbox}&bounded=1&limit=30&addressdetails=1&extratags=1`;
    try {
      const items = await fetchJson(hospitalSearchUrl, 8000);
      if (Array.isArray(items)) {
        for (const item of items) {
          const parsed = parseNominatimItem(item, lat, lng);
          if (parsed && !deduplicated.has(parsed.id)) {
            deduplicated.set(parsed.id, parsed);
          }
        }
      }
    } catch (e) {
      console.warn('[HOSPITAL CONTROLLER] Nominatim hospital search note:', e.message);
    }

    // 2. If results are sparse (< 5), query clinics in the same viewbox
    if (deduplicated.size < 5) {
      const clinicSearchUrl = `https://nominatim.openstreetmap.org/search?format=json&amenity=clinic&viewbox=${viewbox}&bounded=1&limit=20&addressdetails=1&extratags=1`;
      try {
        const items = await fetchJson(clinicSearchUrl, 6000);
        if (Array.isArray(items)) {
          for (const item of items) {
            const parsed = parseNominatimItem(item, lat, lng);
            if (parsed && !deduplicated.has(parsed.id)) {
              deduplicated.set(parsed.id, parsed);
            }
          }
        }
      } catch (e) {
        console.warn('[HOSPITAL CONTROLLER] Nominatim clinic search note:', e.message);
      }
    }

    // 3. If still sparse and city is known, query city text search
    if (deduplicated.size < 3 && city) {
      const cityHospitalUrl = `https://nominatim.openstreetmap.org/search?format=json&q=hospital+${encodeURIComponent(city)}&limit=15&addressdetails=1&extratags=1`;
      try {
        const items = await fetchJson(cityHospitalUrl, 6000);
        if (Array.isArray(items)) {
          for (const item of items) {
            const parsed = parseNominatimItem(item, lat, lng);
            if (parsed && !deduplicated.has(parsed.id)) {
              deduplicated.set(parsed.id, parsed);
            }
          }
        }
      } catch (e) {
        console.warn('[HOSPITAL CONTROLLER] Nominatim city text search note:', e.message);
      }
    }

    // Sort: Verified emergency first, then by distance ascending
    const hospitalList = Array.from(deduplicated.values());
    hospitalList.sort((a, b) => {
      if (a.emergencyServiceVerified !== b.emergencyServiceVerified) {
        return a.emergencyServiceVerified ? -1 : 1;
      }
      return a.distanceMeters - b.distanceMeters;
    });

    // Save in cache if results found
    if (hospitalList.length > 0) {
      searchCache.set(cacheKey, { timestamp: Date.now(), data: hospitalList });
    }

    return res.json({
      success: true,
      count: hospitalList.length,
      radiusMeters: radius,
      cached: false,
      location: {
        latitude: lat,
        longitude: lng,
        cityName: city || null,
      },
      hospitals: hospitalList,
    });
  } catch (error) {
    console.error('[HOSPITAL CONTROLLER ERROR]:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to search healthcare facilities.',
      error: error.message,
    });
  }
};
