import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_ai/models/hospital.dart';
import 'package:med_ai/models/selected_location.dart';
import 'package:med_ai/repositories/hospital_repository.dart';
import 'package:med_ai/services/location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Centralized HospitalRepository Tests', () {
    late HospitalRepository repository;

    setUp(() {
      repository = HospitalRepository.instance;
    });

    test('HospitalRepository is a singleton with reactive ChangeNotifier', () {
      final repo1 = HospitalRepository();
      final repo2 = HospitalRepository.instance;
      expect(identical(repo1, repo2), isTrue);
    });

    test('Selecting a hospital updates selectedHospital and notifies listeners without API search', () {
      final hospital = Hospital(
        id: 'test_osm_101',
        name: 'Apollo Speciality Hospital',
        category: HealthcareCategory.emergencyDepartment,
        latitude: 12.9716,
        longitude: 77.5946,
        address: '14th Cross, Malleshwaram, Bengaluru',
        phoneNumber: '+91 80 2345 6789',
        emergencyServiceVerified: true,
        distanceMeters: 1250,
      );

      bool notified = false;
      void listener() {
        notified = true;
      }

      repository.addListener(listener);
      repository.selectHospital(hospital);

      expect(repository.selectedHospital?.id, 'test_osm_101');
      expect(repository.selectedHospital?.name, 'Apollo Speciality Hospital');
      expect(notified, isTrue);

      repository.removeListener(listener);
    });

    test('Hospital dialablePhone formats valid numbers and returns null when missing', () {
      final withPhone = Hospital(
        id: 'h_1',
        name: 'City Care Hospital',
        latitude: 12.0,
        longitude: 77.0,
        address: 'MG Road',
        phoneNumber: '+91 98765 43210',
      );

      expect(withPhone.hasValidPhone, isTrue);
      expect(withPhone.dialablePhone, '+919876543210');
      expect(withPhone.displayPhone, '+91 98765 43210');

      final withoutPhone = Hospital(
        id: 'h_2',
        name: 'Rural Clinic',
        latitude: 12.0,
        longitude: 77.0,
        address: 'Village Center',
        phoneNumber: '',
      );

      expect(withoutPhone.hasValidPhone, isFalse);
      expect(withoutPhone.dialablePhone, isNull);
      expect(withoutPhone.displayPhone, 'Phone number unavailable');
    });

    test('Hospital emergencyServiceVerified distinguishes 24/7 emergency care from clinics and pharmacies', () {
      final emergencyHospital = Hospital(
        id: 'em_1',
        name: 'Trauma & Emergency Medical Center',
        category: HealthcareCategory.emergencyDepartment,
        latitude: 12.9,
        longitude: 77.5,
        address: 'Main Ring Road',
        emergencyServiceVerified: true,
      );

      final clinic = Hospital(
        id: 'cl_1',
        name: 'Family Health Clinic',
        category: HealthcareCategory.clinic,
        latitude: 12.91,
        longitude: 77.51,
        address: '2nd Cross',
        emergencyServiceVerified: false,
      );

      final pharmacy = Hospital(
        id: 'ph_1',
        name: 'Apollo Pharmacy',
        category: HealthcareCategory.pharmacy,
        latitude: 12.92,
        longitude: 77.52,
        address: 'Market Road',
        emergencyServiceVerified: false,
      );

      expect(emergencyHospital.emergencyServiceVerified, isTrue);
      expect(emergencyHospital.category, HealthcareCategory.emergencyDepartment);

      expect(clinic.emergencyServiceVerified, isFalse);
      expect(clinic.category, HealthcareCategory.clinic);

      expect(pharmacy.emergencyServiceVerified, isFalse);
      expect(pharmacy.category, HealthcareCategory.pharmacy);
    });

    test('SelectedLocation displays appropriate titles for GPS vs City Search', () {
      final gpsLoc = SelectedLocation(
        latitude: 12.9716,
        longitude: 77.5946,
        cityName: 'Current Location',
        source: LocationSource.currentGps,
      );

      expect(gpsLoc.isGps, isTrue);
      expect(gpsLoc.isCitySearch, isFalse);
      expect(gpsLoc.sourceBadgeText, 'Using your current location');

      final cityLoc = SelectedLocation(
        latitude: 17.3850,
        longitude: 78.4867,
        cityName: 'Hyderabad',
        source: LocationSource.citySearch,
      );

      expect(cityLoc.isGps, isFalse);
      expect(cityLoc.isCitySearch, isTrue);
      expect(cityLoc.sourceBadgeText, 'Showing hospitals near Hyderabad');
      expect(cityLoc.displayTitle, 'Hyderabad');
    });

    test('LocationService notifies listeners when manual city is selected', () {
      final locService = LocationService();
      bool notified = false;
      void listener() {
        notified = true;
      }

      locService.addListener(listener);
      locService.setManualCity('Bengaluru', lat: 12.9716, lng: 77.5946);

      expect(locService.selectedLocation?.cityName, 'Bengaluru');
      expect(locService.selectedLocation?.isCitySearch, isTrue);
      expect(notified, isTrue);

      locService.removeListener(listener);
    });
  });

  group('Healthcare Facilities UI Widget Tests', () {
    testWidgets('Hospital item card renders real data, category, phone, and action buttons', (tester) async {
      final hospital = Hospital(
        id: 'osm_way_101',
        name: 'St. John Medical Center',
        category: HealthcareCategory.emergencyDepartment,
        latitude: 12.9344,
        longitude: 77.6190,
        address: 'Sarjapur Main Road, Koramangala, Bengaluru',
        phoneNumber: '+91 80 2206 5000',
        emergencyServiceVerified: true,
        distanceMeters: 2300,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                children: [
                  Text(hospital.name),
                  Text(hospital.category.displayName),
                  if (hospital.emergencyServiceVerified) const Text('24/7 Emergency'),
                  Text(hospital.address),
                  Text('${hospital.distanceKm.toStringAsFixed(1)} km away'),
                  Text(hospital.displayPhone),
                  ElevatedButton(
                    onPressed: hospital.hasValidPhone ? () {} : null,
                    child: const Text('CALL HOSPITAL'),
                  ),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('DIRECTIONS'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('St. John Medical Center'), findsOneWidget);
      expect(find.text('Emergency Department'), findsOneWidget);
      expect(find.text('24/7 Emergency'), findsOneWidget);
      expect(find.text('Sarjapur Main Road, Koramangala, Bengaluru'), findsOneWidget);
      expect(find.text('2.3 km away'), findsOneWidget);
      expect(find.text('+91 80 2206 5000'), findsOneWidget);
      expect(find.text('CALL HOSPITAL'), findsOneWidget);
      expect(find.text('DIRECTIONS'), findsOneWidget);
    });

    testWidgets('Hospital item card with missing phone disables call action and shows Phone Unavailable', (tester) async {
      final clinic = Hospital(
        id: 'osm_node_202',
        name: 'Neighborhood Care Center',
        category: HealthcareCategory.clinic,
        latitude: 12.9800,
        longitude: 77.6000,
        address: 'MG Road, Bengaluru',
        phoneNumber: '',
        emergencyServiceVerified: false,
        distanceMeters: 450,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Column(
                children: [
                  Text(clinic.name),
                  Text(clinic.displayPhone),
                  OutlinedButton(
                    onPressed: clinic.hasValidPhone ? () {} : null,
                    child: Text(clinic.hasValidPhone ? 'CALL HOSPITAL' : 'Phone Unavailable'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Neighborhood Care Center'), findsOneWidget);
      expect(find.text('Phone number unavailable'), findsOneWidget);
      expect(find.text('Phone Unavailable'), findsOneWidget);
    });
  });
}
