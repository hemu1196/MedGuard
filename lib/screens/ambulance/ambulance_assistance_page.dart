import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme.dart';
import '../../models/emergency_contact.dart';
import '../../models/hospital.dart';
import '../../models/selected_location.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/emergency_contact_repository.dart';
import '../../services/hospital_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/emergency_contact_dialog.dart';
import '../../widgets/loading_view.dart';

class AmbulanceAssistancePage extends StatefulWidget {
  const AmbulanceAssistancePage({super.key});

  @override
  State<AmbulanceAssistancePage> createState() => _AmbulanceAssistancePageState();
}

class _AmbulanceAssistancePageState extends State<AmbulanceAssistancePage> {
  final LocationService _locationService = LocationService();
  final HospitalService _hospitalService = HospitalService();
  final EmergencyContactRepository _contactRepository = EmergencyContactRepository();
  final AuthRepository _authRepository = AuthRepository();
  final TextEditingController _citySearchController = TextEditingController();

  String? _currentUserId;
  SelectedLocation? _selectedLocation;
  List<Hospital> _nearbyFacilities = [];
  bool _isLoadingFacilities = true;
  String? _facilityError;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _citySearchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    final userId = await _authRepository.getCurrentUserId();
    if (mounted) {
      setState(() {
        _currentUserId = userId;
      });
    }
    await _fetchLocationAndFacilities();
  }

  Future<void> _fetchLocationAndFacilities({bool forceGpsReset = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingFacilities = true;
      _facilityError = null;
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
          _nearbyFacilities = result.hospitals;
          _selectedLocation = result.location;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _facilityError = 'Unable to load nearby healthcare facilities.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFacilities = false;
        });
      }
    }
  }

  Future<void> _searchCity(String cityQuery) async {
    final query = cityQuery.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoadingFacilities = true;
      _facilityError = null;
    });

    try {
      final loc = await _locationService.geocodeCity(query);
      if (loc == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not find location for "$query". Please check spelling.')),
          );
          setState(() {
            _isLoadingFacilities = false;
          });
        }
        return;
      }

      final result = await _hospitalService.searchHospitalsForLocation(loc);

      if (mounted) {
        setState(() {
          _selectedLocation = result.location;
          _nearbyFacilities = result.hospitals;
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
          _isLoadingFacilities = false;
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
              'Enter a city name to locate emergency care facilities in that area:',
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

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number configured.')),
        );
      }
      return;
    }

    final Uri phoneUri = Uri.parse('tel:$cleanNumber');
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Calling is not supported on this device.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calling is not supported on this device.')),
        );
      }
    }
  }

  void _confirmEmergencyCall(String number, String label) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.phone_in_talk, color: AppColors.emergency),
            SizedBox(width: 8),
            Text('Confirm Call for Help'),
          ],
        ),
        content: Text('Are you sure you want to call emergency services ($label - $number)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency),
            onPressed: () {
              Navigator.of(context).pop();
              _makePhoneCall(number);
            },
            child: const Text('Call Now'),
          ),
        ],
      ),
    );
  }

  void _showAddContactDialog() async {
    await showEmergencyContactDialog(
      context,
      onSaved: () {
        if (mounted) setState(() {});
      },
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
            SnackBar(content: Text('Opening directions for ${h.name}...')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Ambulance Assistance',
        subtitle: 'Location-based emergency help & medical response',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. CURRENT LOCATION
              _buildLocationBanner(),
              const SizedBox(height: 16),

              // 2. CALL FOR HELP (Prominent Red Emergency Button)
              _buildCallForHelpSection(),
              const SizedBox(height: 20),

              // 3. SAVED EMERGENCY CONTACTS
              _buildSavedContactsSection(),
              const SizedBox(height: 20),

              // 4. MAP CANVAS PREVIEW
              _buildMapPreviewBox(),
              const SizedBox(height: 20),

              // 5. NEARBY EMERGENCY HEALTHCARE
              _buildNearbyHealthcareSection(),
              const SizedBox(height: 20),

              // 6. SAFETY NOTE
              _buildSafetyDisclaimerCard(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationBanner() {
    final isCitySearch = _selectedLocation?.isCitySearch ?? false;
    final badgeText = _selectedLocation?.badgeText ?? 'Acquiring GPS coordinates...';

    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isCitySearch ? Icons.location_city : Icons.my_location,
                      color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LOCATION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                            ),
                          ),
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
                    icon: const Icon(Icons.refresh, size: 20),
                    color: AppTheme.primaryTeal,
                    tooltip: 'Refresh Location',
                    onPressed: () => _fetchLocationAndFacilities(),
                  ),
                ],
              ),
            ],
          ),
          if (isCitySearch) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _fetchLocationAndFacilities(forceGpsReset: true),
                icon: const Icon(Icons.my_location, size: 14),
                label: const Text('Use My Current Location', style: TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryTeal,
                  side: const BorderSide(color: AppTheme.primaryTeal),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallForHelpSection() {
    return Card(
      color: const Color(0xFFFEF2F2),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.emergency, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning_amber_rounded, color: AppColors.emergency, size: 24),
                SizedBox(width: 8),
                Text(
                  'CALL FOR HELP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emergency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Immediate emergency phone dispatch for life-threatening situations.',
              style: TextStyle(fontSize: 12, color: AppTheme.textDark),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _confirmEmergencyCall('108', 'National Emergency Line'),
                icon: const Icon(Icons.phone_in_talk, color: Colors.white),
                label: const Text(
                  'CALL EMERGENCY SERVICES (108 / 911)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emergency,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedContactsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SAVED EMERGENCY CONTACTS',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: 0.5),
            ),
            TextButton.icon(
              onPressed: _showAddContactDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Contact', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_currentUserId == null)
          const LoadingView(message: 'Loading contacts...')
        else
          StreamBuilder<List<EmergencyContact>>(
            stream: _contactRepository.watchEmergencyContacts(_currentUserId!),
            builder: (context, snapshot) {
              final contacts = snapshot.data ?? [];

              if (contacts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'No emergency contacts added.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      OutlinedButton(
                        onPressed: _showAddContactDialog,
                        child: const Text('Add Now'),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: contacts.map((c) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.12),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'E',
                          style: const TextStyle(color: AppTheme.primaryTeal, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${c.relationship} • ${c.fullPhoneNumber}', style: const TextStyle(fontSize: 12)),
                      trailing: ElevatedButton.icon(
                        onPressed: () => _makePhoneCall(c.phone),
                        icon: const Icon(Icons.call, size: 14),
                        label: const Text('Call'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMapPreviewBox() {
    final isCitySearch = _selectedLocation?.isCitySearch ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'EMERGENCY MAP PREVIEW',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Stack(
              children: [
                CustomPaint(size: Size.infinite, painter: _SimpleMapGridPainter()),
                Positioned(
                  left: 100,
                  top: 70,
                  child: Column(
                    children: [
                      Icon(
                        isCitySearch ? Icons.location_city : Icons.my_location,
                        color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                        size: 24,
                      ),
                      Text(
                        isCitySearch ? (_selectedLocation?.cityName ?? 'City') : 'You',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                ..._nearbyFacilities.take(3).toList().asMap().entries.map((e) {
                  final idx = e.key;
                  final f = e.value;
                  return Positioned(
                    left: 60.0 + (idx * 80.0),
                    top: 40.0 + (idx * 40.0),
                    child: Column(
                      children: [
                        const Icon(Icons.local_hospital, color: AppColors.emergency, size: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                          child: Text(f.name.split(' ').first, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNearbyHealthcareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEARBY EMERGENCY HEALTHCARE',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),
        if (_isLoadingFacilities)
          const LoadingView(message: 'Searching nearby emergency care facilities...')
        else if (_facilityError != null)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text(_facilityError!, style: const TextStyle(fontSize: 12, color: AppTheme.textDark))),
                ElevatedButton.icon(
                  onPressed: () => _fetchLocationAndFacilities(),
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Retry'),
                ),
              ],
            ),
          )
        else if (_nearbyFacilities.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No emergency healthcare facilities found near ${_selectedLocation?.displayTitle ?? 'your location'}.',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _showCitySearchDialog,
                  icon: const Icon(Icons.location_city, size: 14),
                  label: const Text('Search by City', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                ),
              ],
            ),
          )
        else
          Column(
            children: _nearbyFacilities.take(3).map((f) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('${f.distanceKm.toStringAsFixed(1)} km away • ${f.address}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _makePhoneCall(f.phone),
                              icon: const Icon(Icons.call, size: 14),
                              label: const Text('Call Facility'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _launchDirections(f),
                              icon: const Icon(Icons.navigation, size: 14),
                              label: const Text('Directions'),
                              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryTeal),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSafetyDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.info_outline, size: 18, color: AppTheme.textMuted),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'SAFETY NOTE: MEDGUARD does not claim an ambulance has been dispatched unless a connected emergency provider explicitly confirms a booking.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleMapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
