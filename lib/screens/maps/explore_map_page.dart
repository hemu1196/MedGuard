import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/hospital.dart';
import '../../models/selected_location.dart';
import '../../services/hospital_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class ExploreMapPage extends StatefulWidget {
  const ExploreMapPage({super.key});

  @override
  State<ExploreMapPage> createState() => _ExploreMapPageState();
}

class _ExploreMapPageState extends State<ExploreMapPage> {
  final HospitalService _hospitalService = HospitalService();
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final TextEditingController _citySearchController = TextEditingController();

  List<Hospital> _hospitals = [];
  Hospital? _selectedHospital;
  SelectedLocation? _selectedLocation;
  bool _isLoading = true;
  String? _errorMessage;
  double _currentZoom = 13.5;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _loadMapData({bool forceGpsReset = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (forceGpsReset) {
        _selectedLocation = await _locationService.getCurrentGpsLocation();
      } else {
        _selectedLocation = await _locationService.ensureLocationLoaded();
      }

      final loc = _selectedLocation ?? await _locationService.getCurrentGpsLocation();
      _selectedLocation = loc;

      final result = await _hospitalService
          .searchHospitalsForLocation(loc)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => HospitalSearchResult(
              hospitals: [],
              maxRadiusMeters: 50000,
              statusMessage: 'Search timeout',
              location: loc,
              searchSource: loc.isGps ? 'gps' : 'city',
            ),
          );

      if (mounted) {
        setState(() {
          _hospitals = result.hospitals;
          _selectedLocation = result.location;
          if (_hospitals.isNotEmpty) {
            _selectedHospital = _hospitals.first;
          } else {
            _selectedHospital = null;
          }
        });

        // Center map to current position
        if (_selectedLocation != null && _selectedLocation!.latitude != 0.0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(
              LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
              _currentZoom,
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load map data. Please check connection.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchCity(String cityQuery) async {
    final query = cityQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final loc = await _locationService.geocodeCity(query);
      if (loc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not find location for "$query". Please check spelling.')),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final result = await _hospitalService.searchHospitalsForLocation(loc);

      if (mounted) {
        setState(() {
          _selectedLocation = result.location;
          _hospitals = result.hospitals;
          if (_hospitals.isNotEmpty) {
            _selectedHospital = _hospitals.first;
          } else {
            _selectedHospital = null;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(
            LatLng(loc.latitude, loc.longitude),
            _currentZoom,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching city: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showCitySearchDialog() {
    _citySearchController.text = '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Hospitals by City'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a city name to explore nearby hospitals in that area:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _citySearchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'City Name',
                hintText: 'e.g. Hyderabad, Mumbai, Bangalore',
                prefixIcon: Icon(Icons.location_city),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (val) {
                Navigator.of(ctx).pop();
                _searchCity(val);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
            onPressed: () {
              Navigator.of(ctx).pop();
              _searchCity(_citySearchController.text);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMapsNavigation(Hospital hospital) async {
    final lat = hospital.latitude;
    final lng = hospital.longitude;
    final query = Uri.encodeComponent('${hospital.name}, ${hospital.address}');

    final Uri url = (lat != 0.0 && lng != 0.0)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening map navigation for ${hospital.name}...')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open map: $e')),
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number available for this facility.')),
        );
      }
      return;
    }
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone number available for this facility.')),
      );
      return;
    }

    final Uri phoneUri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Facility Phone Number'),
              content: SelectableText(
                'Phone: $phoneNumber\n\nDirect calling is not supported in this browser or device. You can copy the number and dial manually.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Facility Phone Number'),
            content: SelectableText('Phone: $phoneNumber'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    }
  }

  void _zoomIn() {
    setState(() {
      _currentZoom = (_currentZoom + 1).clamp(3.0, 18.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() {
      _currentZoom = (_currentZoom - 1).clamp(3.0, 18.0);
    });
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _recenterOnUser() {
    if (_selectedLocation != null && _selectedLocation!.latitude != 0.0) {
      _mapController.move(
        LatLng(_selectedLocation!.latitude, _selectedLocation!.longitude),
        _currentZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Explore Map',
        subtitle: 'Interactive map & emergency healthcare routes',
      ),
      body: SafeArea(
        child: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const LoadingView(message: 'Loading interactive map & nearby facilities...');
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.emergency, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadMapData,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Map Search'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
              ),
            ],
          ),
        ),
      );
    }

    final isCitySearch = _selectedLocation?.isCitySearch ?? false;
    final badgeText = _selectedLocation?.badgeText ?? 'Using your current location';
    final centerLat = _selectedLocation?.latitude ?? 17.3850;
    final centerLng = _selectedLocation?.longitude ?? 78.4867;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Badge Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isCitySearch
                  ? Colors.amber.shade50
                  : AppTheme.primaryTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCitySearch
                    ? Colors.amber.shade300
                    : AppTheme.primaryTeal.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isCitySearch ? Icons.location_city : Icons.my_location,
                        color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search, size: 20),
                      color: AppTheme.primaryTeal,
                      tooltip: 'Search City',
                      onPressed: _showCitySearchDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      color: AppTheme.primaryTeal,
                      tooltip: 'Refresh Location & Facilities',
                      onPressed: () => _loadMapData(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isCitySearch) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _loadMapData(forceGpsReset: true),
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Use My Current Location'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: const BorderSide(color: AppTheme.primaryTeal),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Real Interactive Geographic Map Container
          SizedBox(
            height: 340,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(centerLat, centerLng),
                      initialZoom: _currentZoom,
                      minZoom: 3.0,
                      maxZoom: 18.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.medguard.app',
                        maxZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          // User Location Pin
                          Marker(
                            point: LatLng(centerLat, centerLng),
                            width: 50,
                            height: 50,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                                    shape: BoxShape.circle,
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                    ],
                                  ),
                                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                                ),
                              ],
                            ),
                          ),
                          // Facility Markers
                          ..._hospitals.map((h) {
                            final isSelected = _selectedHospital?.id == h.id;
                            final isEmergency = h.emergencyServiceVerified;
                            final markerColor = isEmergency
                                ? AppTheme.accentRed
                                : (h.category == HealthcareCategory.clinic
                                    ? AppTheme.secondaryBlue
                                    : (h.category == HealthcareCategory.pharmacy
                                        ? Colors.orange.shade800
                                        : AppTheme.primaryTeal));

                            return Marker(
                              point: LatLng(h.latitude, h.longitude),
                              width: isSelected ? 48 : 36,
                              height: isSelected ? 48 : 36,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedHospital = h;
                                  });
                                  _mapController.move(LatLng(h.latitude, h.longitude), 14.5);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected ? markerColor : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: markerColor,
                                      width: isSelected ? 3 : 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: markerColor.withValues(alpha: isSelected ? 0.4 : 0.2),
                                        blurRadius: isSelected ? 8 : 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isEmergency
                                        ? Icons.emergency
                                        : (h.category == HealthcareCategory.pharmacy
                                            ? Icons.local_pharmacy
                                            : Icons.local_hospital),
                                    size: isSelected ? 24 : 18,
                                    color: isSelected ? Colors.white : markerColor,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),

                  // Floating Map Action Controls
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_in',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.textDark,
                          onPressed: _zoomIn,
                          child: const Icon(Icons.add),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: 'map_zoom_out',
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.textDark,
                          onPressed: _zoomOut,
                          child: const Icon(Icons.remove),
                        ),
                        const SizedBox(height: 6),
                        FloatingActionButton.small(
                          heroTag: 'map_recenter',
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                          onPressed: _recenterOnUser,
                          child: const Icon(Icons.my_location),
                        ),
                      ],
                    ),
                  ),

                  // Map Attribution Badge
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 9, color: Colors.black87),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Selected Hospital Detail Card
          if (_selectedHospital != null) ...[
            Builder(
              builder: (context) {
                final h = _selectedHospital!;
                final hasPhone = h.hasValidPhone;

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.name,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    h.address,
                                    style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              alignment: WrapAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    h.category.displayName,
                                    style: const TextStyle(
                                      color: AppTheme.primaryTeal,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (h.emergencyServiceVerified)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '24/7 Emergency',
                                      style: TextStyle(
                                        color: AppTheme.accentRed,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoChip(
                                Icons.near_me_outlined,
                                'Distance',
                                '${h.distanceKm.toStringAsFixed(1)} km',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInfoChip(
                                hasPhone ? Icons.call_outlined : Icons.phone_disabled_outlined,
                                'Phone',
                                h.displayPhone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time_outlined, size: 14, color: AppTheme.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              h.openingHoursDisplay,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: hasPhone ? () => _launchPhoneCall(h.dialablePhone) : null,
                                icon: Icon(
                                  hasPhone ? Icons.call : Icons.phone_disabled,
                                  size: 16,
                                ),
                                label: Text(hasPhone ? 'Call Hospital' : 'Phone Unavailable'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _launchMapsNavigation(h),
                                icon: const Icon(Icons.navigation, size: 16),
                                label: const Text('Start Route'),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryTeal),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
