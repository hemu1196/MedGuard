import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
    // Fetch emergency contacts from API to warm up stream and sync from backend
    if (userId.isNotEmpty) {
      _contactRepository.getContactsFromApi(userId: userId);
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

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid phone number configured.')),
        );
      }
      return;
    }
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
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Call Details'),
              content: SelectableText(
                'Number: $phoneNumber\n\nDirect calling is not supported in this browser or device. You can copy this number to dial manually.',
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Call Details'),
            content: SelectableText('Number: $phoneNumber'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
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
              // 1. CURRENT LOCATION BANNER
              _buildLocationBanner(),
              const SizedBox(height: 16),

              // 2. CALL FOR HELP (Regional Emergency Service Numbers)
              _buildCallForHelpSection(),
              const SizedBox(height: 20),

              // 3. SAVED EMERGENCY CONTACTS
              _buildSavedContactsSection(),
              const SizedBox(height: 20),

              // 4. REAL GEOGRAPHIC MAP PREVIEW
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
                  'IMMEDIATE EMERGENCY DISPATCH',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.emergency,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Direct emergency tele-dispatch for critical and life-threatening situations.',
              style: TextStyle(fontSize: 12, color: AppTheme.textDark),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmEmergencyCall('108', 'Emergency Ambulance Service (India)'),
                    icon: const Icon(Icons.medical_services_outlined, size: 18, color: Colors.white),
                    label: const Text(
                      'AMBULANCE (108)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emergency,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmEmergencyCall('112', 'National Emergency Line (India)'),
                    icon: const Icon(Icons.emergency, size: 18, color: Colors.white),
                    label: const Text(
                      'NATIONAL SOS (112)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
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
            builder: (streamContext, snapshot) {
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
                        'No emergency contacts configured.',
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
                        backgroundColor: c.isPrimary
                            ? AppColors.emergency.withValues(alpha: 0.15)
                            : AppTheme.primaryTeal.withValues(alpha: 0.12),
                        child: Text(
                          c.name.isNotEmpty ? c.name[0].toUpperCase() : 'E',
                          style: TextStyle(
                            color: c.isPrimary ? AppColors.emergency : AppTheme.primaryTeal,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (c.isPrimary)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: const Text(
                                'PRIMARY',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emergency,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${c.displayRelationship} • ${c.fullPhoneNumber}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _makePhoneCall(c.dialablePhone),
                            icon: const Icon(Icons.call, size: 14),
                            label: const Text('Call'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryTeal,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (val) async {
                              if (val == 'edit') {
                                await showEmergencyContactDialog(
                                  context,
                                  existing: c,
                                  onSaved: () {
                                    if (mounted) setState(() {});
                                  },
                                );
                              } else if (val == 'primary') {
                                await _contactRepository.setPrimaryContact(_currentUserId!, c.id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${c.name} set as primary contact')),
                                );
                              } else if (val == 'delete') {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete Contact'),
                                    content: Text('Are you sure you want to delete ${c.name}?'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.emergency),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _contactRepository.deleteEmergencyContact(_currentUserId!, c.id);
                                }
                              }
                            },
                            itemBuilder: (ctx) => [
                              if (!c.isPrimary)
                                const PopupMenuItem(value: 'primary', child: Text('Set as Primary')),
                              const PopupMenuItem(value: 'edit', child: Text('Edit Contact')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete Contact', style: TextStyle(color: AppColors.emergency))),
                            ],
                          ),
                        ],
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
    final centerLat = _selectedLocation?.latitude ?? 17.3850;
    final centerLng = _selectedLocation?.longitude ?? 78.4867;
    final isCitySearch = _selectedLocation?.isCitySearch ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE GEOGRAPHIC MAP PREVIEW',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textDark, letterSpacing: 0.5),
            ),
            Text(
              '${_nearbyFacilities.length} facilities nearby',
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLng),
                    initialZoom: 13.0,
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
                        // Center user marker
                        Marker(
                          point: LatLng(centerLat, centerLng),
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isCitySearch ? Colors.amber.shade900 : AppTheme.primaryTeal,
                              shape: BoxShape.circle,
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                          ),
                        ),
                        // Nearby facility markers
                        ..._nearbyFacilities.take(8).map((f) {
                          final isEmergency = f.emergencyServiceVerified;
                          return Marker(
                            point: LatLng(f.latitude, f.longitude),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isEmergency ? AppTheme.accentRed : AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                              ),
                              child: Icon(
                                isEmergency ? Icons.emergency : Icons.local_hospital,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ],
                ),
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
            children: _nearbyFacilities.take(4).map((f) {
              final hasPhone = f.hasValidPhone;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              f.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 4,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  f.category.displayName,
                                  style: const TextStyle(color: AppTheme.primaryTeal, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (f.emergencyServiceVerified)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '24/7',
                                    style: TextStyle(color: AppTheme.accentRed, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${f.distanceKm.toStringAsFixed(1)} km away • ${f.address}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasPhone ? 'Phone: ${f.displayPhone}' : 'Phone number unavailable',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: hasPhone ? FontWeight.w600 : FontWeight.normal,
                          color: hasPhone ? AppTheme.secondaryBlue : AppColors.textDisabled,
                        ),
                      ),
                      const Divider(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: hasPhone ? () => _makePhoneCall(f.dialablePhone) : null,
                              icon: Icon(hasPhone ? Icons.call : Icons.phone_disabled, size: 14),
                              label: Text(hasPhone ? 'Call Facility' : 'Phone Unavailable'),
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
              'SAFETY NOTE: MEDGUARD emergency calling initiates native tele-dispatch to emergency services. MEDGUARD does not claim an ambulance has arrived until confirmed directly by the operating provider.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted, fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}
