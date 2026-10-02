import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/hospital.dart';
import '../../repositories/hospital_repository.dart';
import '../../services/hospital_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_view.dart';

class NearbyHospitalsPage extends StatefulWidget {
  const NearbyHospitalsPage({super.key});

  @override
  State<NearbyHospitalsPage> createState() => _NearbyHospitalsPageState();
}

enum HospitalSearchState { initial, loading, loaded, empty, permissionDenied, gpsDisabled, error }

class _NearbyHospitalsPageState extends State<NearbyHospitalsPage> {
  HospitalSearchState _state = HospitalSearchState.initial;
  final LocationService _locationService = LocationService();
  final HospitalRepository _hospitalRepository = HospitalRepository();
  final TextEditingController _citySearchController = TextEditingController();

  List<Hospital> _hospitals = [];
  String? _errorMessage;
  String _loadingStatus = 'Getting your location...';
  int _maxRadiusMeters = 5000;

  @override
  void initState() {
    super.initState();
    _loadInitialLocationAndHospitals();
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  void _loadInitialLocationAndHospitals() async {
    if (_locationService.selectedLocation != null) {
      _searchHospitalsForCurrentSelectedLocation();
    } else {
      _useMyLocation();
    }
  }

  void _useMyLocation() async {
    setState(() {
      _state = HospitalSearchState.loading;
      _loadingStatus = 'Getting your location...';
      _errorMessage = null;
    });

    try {
      final loc = await _locationService.requestLocation().timeout(
        const Duration(seconds: 10),
        onTimeout: () => null,
      );

      if (!mounted) return;

      if (loc == null) {
        final perm = _locationService.permissionState;
        if (perm == LocationPermissionState.disabled) {
          setState(() => _state = HospitalSearchState.gpsDisabled);
        } else if (perm == LocationPermissionState.denied) {
          setState(() => _state = HospitalSearchState.permissionDenied);
        } else {
          setState(() {
            _errorMessage = 'Unable to determine your current location. Please try again.';
            _state = HospitalSearchState.error;
          });
        }
        return;
      }

      _searchHospitalsForCurrentSelectedLocation();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to search nearby hospitals. Please verify network and location settings.';
          _state = HospitalSearchState.error;
        });
      }
    }
  }

  void _searchHospitalsForCurrentSelectedLocation({bool forceRefresh = false}) async {
    final selLoc = _locationService.selectedLocation;
    if (selLoc == null) {
      _useMyLocation();
      return;
    }

    setState(() {
      _state = HospitalSearchState.loading;
      _loadingStatus = selLoc.isGps
          ? 'Finding nearby hospitals...'
          : 'Searching hospitals near ${selLoc.cityName ?? "location"}...';
      _errorMessage = null;
    });

    try {
      final HospitalSearchResult result = await _hospitalRepository.searchHospitalsForLocation(
        selLoc,
        forceRefresh: forceRefresh,
        onProgress: (status) {
          if (mounted) {
            setState(() {
              _loadingStatus = status;
            });
          }
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => HospitalSearchResult(
          hospitals: [],
          maxRadiusMeters: 50000,
          statusMessage: 'Location search timed out.',
          location: selLoc,
          searchSource: selLoc.isGps ? 'gps' : 'city',
        ),
      );

      if (!mounted) return;

      setState(() {
        _hospitals = result.hospitals;
        _maxRadiusMeters = result.maxRadiusMeters;
        _state = result.hospitals.isEmpty ? HospitalSearchState.empty : HospitalSearchState.loaded;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load hospitals. Please try again.';
          _state = HospitalSearchState.error;
        });
      }
    }
  }

  void _performCitySearch(String cityQuery) async {
    final query = cityQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _state = HospitalSearchState.loading;
      _loadingStatus = 'Geocoding $query...';
      _errorMessage = null;
    });

    try {
      final selLoc = await _locationService.geocodeCity(query);
      if (!mounted) return;

      if (selLoc != null) {
        _searchHospitalsForCurrentSelectedLocation();
      } else {
        setState(() {
          _errorMessage = 'Location not found. Please enter a valid city or location.';
          _state = HospitalSearchState.error;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _state = HospitalSearchState.error;
        });
      }
    }
  }

  void _showCitySearchModal() {
    _citySearchController.text = _locationService.selectedLocation?.cityName ?? '';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Search Hospitals by City'),
        content: TextField(
          controller: _citySearchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Hyderabad, Chennai, Chicago',
            prefixIcon: Icon(Icons.location_city),
          ),
          onSubmitted: (val) {
            Navigator.of(dialogContext).pop();
            _performCitySearch(val);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = _citySearchController.text.trim();
              Navigator.of(dialogContext).pop();
              _performCitySearch(val);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchDirections(Hospital h) async {
    final lat = h.latitude;
    final lng = h.longitude;
    final query = Uri.encodeComponent('${h.name}, ${h.address}');

    final Uri googleMapsUrl = (lat != 0.0 && lng != 0.0)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening map route to ${h.name}...')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening directions for ${h.name}')),
        );
      }
    }
  }

  Future<void> _makePhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Calling $phone...')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Calling $phone...')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Nearby Hospitals',
        subtitle: 'Emergency centers & hospitals nearby',
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildLocationBadgeHeader() {
    final selLoc = _locationService.selectedLocation;
    final isGps = selLoc?.isGps ?? true;
    final titleText = selLoc?.sourceBadgeText ?? 'Using your current location';
    final radiusKm = _maxRadiusMeters ~/ 1000;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryTeal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isGps ? Icons.my_location : Icons.location_city,
                color: AppTheme.primaryTeal,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titleText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Showing ${_hospitals.length} hospital(s) within $radiusKm km',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _searchHospitalsForCurrentSelectedLocation(forceRefresh: true),
                icon: const Icon(Icons.refresh_rounded, color: AppTheme.primaryTeal),
                tooltip: 'Refresh Search',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (!isGps) ...[
                ElevatedButton.icon(
                  onPressed: _useMyLocation,
                  icon: const Icon(Icons.my_location, size: 14),
                  label: const Text('Use My Current Location', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              OutlinedButton.icon(
                onPressed: _showCitySearchModal,
                icon: const Icon(Icons.search, size: 14),
                label: const Text('Search by City', style: TextStyle(fontSize: 11)),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    switch (_state) {
      case HospitalSearchState.initial:
      case HospitalSearchState.loading:
        return LoadingView(
          message: _loadingStatus,
        );

      case HospitalSearchState.loaded:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLocationBadgeHeader(),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: _hospitals.length,
                itemBuilder: (context, index) {
                  final h = _hospitals[index];
                  final hasPhone = h.phone.trim().isNotEmpty && RegExp(r'\d').hasMatch(h.phone);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  '${index + 1}. ${h.name}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: onSurface,
                                  ),
                                ),
                              ),
                              if (h.hasEmergencyServices)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    '24/7 Emergency',
                                    style: TextStyle(
                                      color: AppTheme.accentRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            h.address,
                            style: TextStyle(
                              fontSize: 13,
                              color: onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_outlined,
                                size: 14,
                                color: AppTheme.primaryTeal,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${h.distanceKm.toStringAsFixed(1)} km away',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.primaryTeal,
                                ),
                              ),
                              if (hasPhone) ...[
                                const SizedBox(width: 16),
                                const Icon(
                                  Icons.call_outlined,
                                  size: 14,
                                  color: AppTheme.secondaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    h.phone,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: AppTheme.secondaryBlue,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (hasPhone)
                                ElevatedButton.icon(
                                  onPressed: () => _makePhoneCall(h.phone),
                                  icon: const Icon(Icons.call, size: 16),
                                  label: const Text('CALL'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.secondaryBlue,
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              else
                                OutlinedButton.icon(
                                  onPressed: null,
                                  icon: const Icon(Icons.phone_disabled, size: 16),
                                  label: const Text('No Phone'),
                                ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () => _launchDirections(h),
                                icon: const Icon(Icons.directions, size: 16),
                                label: const Text('DIRECTIONS'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryTeal,
                                  foregroundColor: Colors.white,
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
            ),
          ],
        );

      case HospitalSearchState.empty:
        return SingleChildScrollView(
          child: Column(
            children: [
              _buildLocationBadgeHeader(),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'No nearby hospitals found.',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Unable to find usable hospitals around this location. Would you like to search by city or location?',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _citySearchController,
                              decoration: const InputDecoration(
                                hintText: 'Enter city (e.g. Hyderabad)',
                                prefixIcon: Icon(Icons.location_city),
                              ),
                              onSubmitted: _performCitySearch,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () => _performCitySearch(_citySearchController.text),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _useMyLocation,
                        icon: const Icon(Icons.my_location),
                        label: const Text('Retry Current Location GPS'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      case HospitalSearchState.permissionDenied:
        return EmptyStateView(
          title: 'Location Permission Required',
          message:
              'Location permission is required to find nearby hospitals around your current location. Please enable location access or search by city.',
          icon: Icons.location_off_outlined,
          actionText: 'Open App Settings',
          onAction: () async {
            await _locationService.openAppSettings();
          },
        );

      case HospitalSearchState.gpsDisabled:
        return EmptyStateView(
          title: 'Location Services Disabled',
          message: 'Please enable Location Services to find nearby hospitals around your current location.',
          icon: Icons.gps_off_outlined,
          actionText: 'Enable Location Services',
          onAction: () async {
            await _locationService.openLocationSettings();
          },
        );

      case HospitalSearchState.error:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppTheme.accentRed,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage ?? 'Unable to determine your current location. Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(color: onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _useMyLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry GPS'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _showCitySearchModal,
                    icon: const Icon(Icons.location_city),
                    label: const Text('Search by City'),
                  ),
                ],
              ),
            ],
          ),
        );
    }
  }
}
