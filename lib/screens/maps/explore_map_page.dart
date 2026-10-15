import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/hospital.dart';
import '../../repositories/hospital_repository.dart';
import '../../services/location_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/loading_view.dart';

class ExploreMapPage extends StatefulWidget {
  const ExploreMapPage({super.key});

  @override
  State<ExploreMapPage> createState() => _ExploreMapPageState();
}

class _ExploreMapPageState extends State<ExploreMapPage> {
  final HospitalRepository _repository = HospitalRepository.instance;
  final LocationService _locationService = LocationService();
  final MapController _mapController = MapController();
  final TextEditingController _citySearchController = TextEditingController();

  double _currentZoom = 13.5;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository.addListener(_onRepositoryUpdated);
    if (_repository.hospitals.isEmpty && !_repository.isLoading) {
      _loadMapData();
    } else {
      _centerMapOnSelected();
    }
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryUpdated);
    _citySearchController.dispose();
    super.dispose();
  }

  void _onRepositoryUpdated() {
    if (!mounted) return;
    setState(() {
      _errorMessage = _repository.errorMessage;
    });
    _centerMapOnSelected();
  }

  void _centerMapOnSelected() {
    final selLoc = _repository.selectedLocation ?? _locationService.selectedLocation;
    if (selLoc != null && selLoc.latitude != 0.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(
            LatLng(selLoc.latitude, selLoc.longitude),
            _currentZoom,
          );
        } catch (_) {}
      });
    }
  }

  Future<void> _loadMapData({bool forceGpsReset = false}) async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      if (forceGpsReset) {
        await _repository.useCurrentGpsLocation(forceRefresh: true);
      } else {
        final selLoc = _repository.selectedLocation ?? _locationService.selectedLocation;
        if (selLoc != null && selLoc.latitude != 0.0) {
          await _repository.searchHospitalsForLocation(selLoc);
        } else {
          await _repository.useCurrentGpsLocation();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('AppException: ', '');
        });
      }
    }
  }

  Future<void> _searchCity(String cityQuery) async {
    final query = cityQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final result = await _repository.searchByCity(query);
      if (mounted && result.location.latitude != 0.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(
            LatLng(result.location.latitude, result.location.longitude),
            _currentZoom,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not find hospitals for "$query": $e')),
        );
      }
    }
  }

  void _showCitySearchDialog() {
    _citySearchController.text = _repository.selectedLocation?.cityName ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Search Hospitals by City'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a city name to explore nearby hospitals on the map:',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _citySearchController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'City Name',
                hintText: 'e.g. Hyderabad, Mumbai, Bengaluru',
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
                'Phone: $phoneNumber\n\nDirect calling is not supported on this platform. You can copy the number and dial manually.',
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
    final selLoc = _repository.selectedLocation ?? _locationService.selectedLocation;
    if (selLoc != null && selLoc.latitude != 0.0) {
      _mapController.move(
        LatLng(selLoc.latitude, selLoc.longitude),
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
    if (_repository.isLoading && _repository.hospitals.isEmpty) {
      return LoadingView(message: _repository.loadingStatus);
    }

    if (_errorMessage != null && _repository.hospitals.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 48),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _loadMapData(forceGpsReset: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry GPS'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showCitySearchDialog,
                    icon: const Icon(Icons.location_city),
                    label: const Text('Search by City'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final selLoc = _repository.selectedLocation ?? _locationService.selectedLocation;
    final isCitySearch = selLoc?.isCitySearch ?? false;
    final badgeText = selLoc?.sourceBadgeText ?? 'Using your current location';
    final centerLat = selLoc?.latitude ?? 17.3850;
    final centerLng = selLoc?.longitude ?? 78.4867;
    final hospitals = _repository.hospitals;
    final selectedH = _repository.selectedHospital ?? (hospitals.isNotEmpty ? hospitals.first : null);

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
                      onPressed: () => _loadMapData(forceGpsReset: !isCitySearch),
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
                          ...hospitals.map((h) {
                            final isSelected = selectedH?.id == h.id;
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
                                  _repository.selectHospital(h);
                                  _mapController.move(LatLng(h.latitude, h.longitude), 14.5);
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    color: markerColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? Colors.yellowAccent : Colors.white,
                                      width: isSelected ? 3.0 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isSelected ? Colors.black45 : Colors.black26,
                                        blurRadius: isSelected ? 8 : 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isEmergency ? Icons.emergency : Icons.local_hospital,
                                    color: Colors.white,
                                    size: isSelected ? 24 : 18,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),

                  // OpenStreetMap Attribution badge
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '© OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10, color: Colors.black87),
                      ),
                    ),
                  ),

                  // Map Floating Controls (Recenter, Zoom In, Zoom Out)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'recenter_btn',
                          onPressed: _recenterOnUser,
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryTeal,
                          child: const Icon(Icons.my_location, size: 20),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_in_btn',
                          onPressed: _zoomIn,
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.textDark,
                          child: const Icon(Icons.add, size: 20),
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                          heroTag: 'zoom_out_btn',
                          onPressed: _zoomOut,
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.textDark,
                          child: const Icon(Icons.remove, size: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Detail Section for Selected Facility
          if (selectedH != null)
            Card(
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
                          child: Text(
                            selectedH.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Wrap(
                          spacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                selectedH.category.displayName,
                                style: const TextStyle(
                                  color: AppTheme.primaryTeal,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            if (selectedH.emergencyServiceVerified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '24/7',
                                  style: TextStyle(
                                    color: AppTheme.accentRed,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      selectedH.address,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 14, color: AppTheme.primaryTeal),
                        const SizedBox(width: 4),
                        Text(
                          '${selectedH.distanceKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryTeal,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          selectedH.hasValidPhone ? Icons.phone : Icons.phone_disabled,
                          size: 14,
                          color: selectedH.hasValidPhone ? AppTheme.secondaryBlue : AppColors.textDisabled,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            selectedH.hasValidPhone ? selectedH.displayPhone : 'Phone unavailable',
                            style: TextStyle(
                              fontSize: 12,
                              color: selectedH.hasValidPhone ? AppTheme.secondaryBlue : AppColors.textDisabled,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.secondaryBlue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: selectedH.hasValidPhone
                                ? () => _launchPhoneCall(selectedH.dialablePhone)
                                : null,
                            icon: const Icon(Icons.call, size: 16),
                            label: Text(selectedH.hasValidPhone ? 'Call Facility' : 'Phone Unavailable'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _launchMapsNavigation(selectedH),
                            icon: const Icon(Icons.navigation, size: 16),
                            label: const Text('Directions'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else if (hospitals.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'No hospitals found near ${selLoc?.cityName ?? "this area"}.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _showCitySearchDialog,
                      icon: const Icon(Icons.location_city, size: 16),
                      label: const Text('Search by City'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
