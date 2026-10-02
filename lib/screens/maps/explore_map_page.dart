import 'package:flutter/material.dart';
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
  final TextEditingController _citySearchController = TextEditingController();

  List<Hospital> _hospitals = [];
  Hospital? _selectedHospital;
  SelectedLocation? _selectedLocation;
  bool _isLoading = true;
  String? _errorMessage;

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

    final Uri googleMapsUrl = (lat != 0.0 && lng != 0.0)
        ? Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')
        : Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening maps route for ${hospital.name}...')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening route to ${hospital.name}')),
        );
      }
    }
  }

  Future<void> _launchPhoneCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) return;

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
    } catch (e) {
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

          if (_hospitals.isEmpty)
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Icon(Icons.search_off, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'No Nearby Hospitals Found',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No hospitals were found near ${_selectedLocation?.displayTitle ?? 'your location'}. Would you like to search by city?',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _showCitySearchDialog,
                      icon: const Icon(Icons.location_city),
                      label: const Text('Search by City'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            // Constrained Map Canvas Box
            SizedBox(
              height: 320,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Stack(
                  children: [
                    // Grid lines / Map pattern simulation
                    CustomPaint(
                      size: Size.infinite,
                      painter: _MapGridPainter(),
                    ),

                    // Center Location Marker Pin
                    Positioned(
                      left: 140,
                      top: 130,
                      child: Column(
                        children: [
                          Icon(
                            isCitySearch ? Icons.location_city : Icons.my_location,
                            color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                            size: 28,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCitySearch ? (_selectedLocation?.cityName ?? 'City') : 'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Hospital Pins
                    ..._hospitals.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final h = entry.value;
                      final isSelected = _selectedHospital?.id == h.id;
                      final double leftPos = 30.0 + ((idx % 4) * 80.0);
                      final double topPos = 40.0 + ((idx ~/ 4) * 85.0);

                      return Positioned(
                        left: leftPos,
                        top: topPos,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedHospital = h;
                            });
                          },
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_hospital,
                                color: isSelected
                                    ? AppTheme.accentRed
                                    : AppTheme.primaryBlue,
                                size: isSelected ? 36 : 28,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentRed
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  h.name.split(' ').first,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : AppTheme.textDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          '📍 Hospital Map Preview',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Selected Destination Card
            if (_selectedHospital != null) ...[
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'SELECTED DESTINATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (_selectedHospital!.hasEmergencyServices)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.accentRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                '🚨 24/7 ER',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentRed,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedHospital!.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedHospital!.address,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildInfoChip(
                            Icons.near_me_outlined,
                            'Distance',
                            '${_selectedHospital!.distanceKm} km',
                          ),
                          const SizedBox(width: 12),
                          _buildInfoChip(
                            Icons.timer_outlined,
                            'Est. Travel Time',
                            '${(_selectedHospital!.distanceKm * 4).round()} mins',
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _launchPhoneCall(_selectedHospital!.phone),
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Call Facility'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _launchMapsNavigation(_selectedHospital!),
                              icon: const Icon(
                                Icons.navigation,
                                size: 16,
                              ),
                              label: const Text('Start Route'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryTeal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryTeal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.primaryTeal),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTeal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
