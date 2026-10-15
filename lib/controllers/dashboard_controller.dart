import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/bmi_calculator.dart';
import '../models/appointment.dart';
import '../models/health_record.dart';
import '../models/hospital.dart';
import '../models/medicine.dart';
import '../models/selected_location.dart';
import '../models/user_profile.dart';
import '../models/water_intake.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_record_repository.dart';
import '../repositories/hospital_repository.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/water_repository.dart';
import '../services/location_service.dart';
import '../services/user_state_service.dart';

class DashboardController extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final HealthRecordRepository _healthRecordRepository = HealthRecordRepository();
  final WaterRepository _waterRepository = WaterRepository();
  final AppointmentRepository _appointmentRepository = AppointmentRepository();
  final HospitalRepository _hospitalRepository = HospitalRepository.instance;
  final LocationService _locationService = LocationService();

  UserProfile? userProfile;
  List<HealthRecord> healthRecords = [];
  List<Medicine> medicines = [];
  List<Hospital> nearbyHospitals = [];
  DailyWaterIntake? dailyWaterIntake;
  Appointment? upcomingAppointment;

  bool isLoadingProfile = true;
  bool isLoadingMedicines = true;
  bool isLoadingRecords = true;
  bool isLoadingHospitals = true;
  bool isLoadingWater = true;
  bool isLoadingAppointments = true;

  String? profileError;
  String? medicinesError;
  String? recordsError;
  String? hospitalsError;

  int unreadNotifications = 0;
  String currentCity = 'My Location';

  StreamSubscription? _profileSub;
  StreamSubscription? _medsSub;
  StreamSubscription? _recordsSub;

  DashboardController() {
    ProfileStateManager.instance.addListener(_onProfileStateChanged);
    userProfile = ProfileStateManager.instance.currentProfile;
    init();
  }

  void _onProfileStateChanged() {
    userProfile = ProfileStateManager.instance.currentProfile;
    isLoadingProfile = ProfileStateManager.instance.isLoading;
    notifyListeners();
  }

  Future<void> init() async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      _subscribeToRealtimeData(userId);
      await Future.wait([
        ProfileStateManager.instance.loadProfile(),
        loadHospitals(),
        loadWater(userId),
        loadAppointments(userId),
      ]);
    } catch (e) {
      debugPrint('[DASHBOARD CONTROLLER] Init error: $e');
      isLoadingProfile = false;
      isLoadingMedicines = false;
      isLoadingRecords = false;
      isLoadingHospitals = false;
      isLoadingWater = false;
      isLoadingAppointments = false;
      profileError = e.toString();
      notifyListeners();
    }
  }

  void _subscribeToRealtimeData(String userId) {
    isLoadingMedicines = true;
    isLoadingRecords = true;
    notifyListeners();

    // 1. Profile via centralized ProfileStateManager
    userProfile = ProfileStateManager.instance.currentProfile;
    isLoadingProfile = ProfileStateManager.instance.isLoading;

    // 2. Medicines Stream
    _medsSub?.cancel();
    _medsSub = _medicineRepository.watchMedicines(userId).listen((list) {
      medicines = list;
      medicinesError = null;
      isLoadingMedicines = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[DASHBOARD] Medicines stream error: $e');
      _loadMedicinesFallback(userId);
    });

    // 3. Health Records Stream
    _recordsSub?.cancel();
    _recordsSub = _healthRecordRepository.watchHealthRecords(userId).listen((list) {
      healthRecords = list;
      recordsError = null;
      isLoadingRecords = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[DASHBOARD] Records stream error: $e');
      _loadRecordsFallback(userId);
    });
  }

  Future<void> _loadMedicinesFallback(String userId) async {
    try {
      medicines = await _medicineRepository.getMedicines(userId: userId);
    } catch (e) {
      medicinesError = 'Failed to load medicines';
    } finally {
      isLoadingMedicines = false;
      notifyListeners();
    }
  }

  Future<void> _loadRecordsFallback(String userId) async {
    try {
      healthRecords = await _healthRecordRepository.getRecords(userId: userId);
      healthRecords.sort((a, b) => b.documentDate.compareTo(a.documentDate));
    } catch (e) {
      recordsError = 'Failed to load records';
    } finally {
      isLoadingRecords = false;
      notifyListeners();
    }
  }

  Future<void> loadHospitals() async {
    isLoadingHospitals = true;
    hospitalsError = null;
    notifyListeners();

    try {
      if (_hospitalRepository.hospitals.isNotEmpty) {
        nearbyHospitals = _hospitalRepository.hospitals;
        currentCity = _hospitalRepository.selectedLocation?.displayTitle ?? 'Current Location';
      } else {
        final SelectedLocation loc = await _locationService.ensureLocationLoaded();
        currentCity = loc.displayTitle;
        final result = await _hospitalRepository.searchHospitalsForLocation(loc);
        nearbyHospitals = result.hospitals;
      }
    } catch (e) {
      debugPrint('[DASHBOARD] Hospital fetch error: $e');
      hospitalsError = 'Unable to load nearby healthcare facilities.';
    } finally {
      isLoadingHospitals = false;
      notifyListeners();
    }
  }

  Future<void> loadWater([String? uid]) async {
    isLoadingWater = true;
    notifyListeners();
    try {
      final userId = uid ?? await _authRepository.getCurrentUserId();
      dailyWaterIntake = await _waterRepository.getTodayWaterIntake(userId: userId);
    } catch (e) {
      debugPrint('[DASHBOARD] Water fetch error: $e');
    } finally {
      isLoadingWater = false;
      notifyListeners();
    }
  }

  Future<void> loadAppointments([String? uid]) async {
    isLoadingAppointments = true;
    notifyListeners();
    try {
      final userId = uid ?? await _authRepository.getCurrentUserId();
      final list = await _appointmentRepository.getAppointments(userId: userId);
      final now = DateTime.now();
      final upcoming = list.where((a) {
        final st = a.status.toLowerCase();
        if (st == 'cancelled' || st == 'completed') return false;
        return a.appointmentDate.isAfter(now.subtract(const Duration(hours: 1)));
      }).toList();
      upcoming.sort((a, b) => a.appointmentDate.compareTo(b.appointmentDate));
      upcomingAppointment = upcoming.isNotEmpty ? upcoming.first : null;
    } catch (e) {
      debugPrint('[DASHBOARD] Appointments fetch error: $e');
    } finally {
      isLoadingAppointments = false;
      notifyListeners();
    }
  }

  String get waterDisplay {
    if (dailyWaterIntake == null) return '0.0L / 2.0L';
    final consumedL = (dailyWaterIntake!.currentMl / 1000.0).toStringAsFixed(1);
    final targetL = (dailyWaterIntake!.targetMl / 1000.0).toStringAsFixed(1);
    return '${consumedL}L / ${targetL}L';
  }

  double get waterProgressRatio {
    return dailyWaterIntake?.progressRatio ?? 0.0;
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get firstName {
    final profile = userProfile ?? ProfileStateManager.instance.currentProfile;
    if (profile == null || profile.name.trim().isEmpty) {
      final email = _authRepository.currentUser?.email ?? FirebaseAuth.instance.currentUser?.email;
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
      return 'User';
    }
    return profile.name.trim().split(' ').first;
  }

  double get bmi {
    if (userProfile == null) return 0.0;
    return userProfile!.bmi;
  }

  String get bmiCategory => BmiCalculator.getBMICategory(bmi);

  String get bmiGuidance => BmiCalculator.getBMIGuidance(bmi);

  int get profileCompletionPercentage {
    if (userProfile == null) return 0;
    int filled = 0;
    const totalFields = 7;

    if (userProfile!.name.trim().isNotEmpty) filled++;
    if (userProfile!.dateOfBirth != null) filled++;
    if (userProfile!.gender.trim().isNotEmpty) filled++;
    if (userProfile!.bloodGroup.trim().isNotEmpty) filled++;
    if (userProfile!.height.trim().isNotEmpty) filled++;
    if (userProfile!.weight.trim().isNotEmpty) filled++;
    if (userProfile!.emergencyPhone.trim().isNotEmpty) filled++;

    return ((filled / totalFields) * 100).round();
  }

  int get activeMedicinesCount {
    return medicines.where((m) => m.quantityAvailable > 0).length;
  }

  List<Medicine> get todaysMedicines {
    // Return all scheduled medicines for display
    return medicines;
  }

  List<HealthRecord> get recentRecords {
    return healthRecords.take(3).toList();
  }

  Map<HealthRecordType, int> get categoryBreakdown {
    final map = <HealthRecordType, int>{};
    for (final r in healthRecords) {
      map[r.recordType] = (map[r.recordType] ?? 0) + 1;
    }
    return map;
  }

  Future<bool> markMedicineTaken(Medicine medicine) async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      final updatedStock = (medicine.quantityAvailable - medicine.dosageQuantity).clamp(0, 9999);
      final updatedMed = Medicine(
        id: medicine.id,
        userId: userId,
        sourceHealthRecordId: medicine.sourceHealthRecordId,
        name: medicine.name,
        dosage: medicine.dosage,
        frequency: medicine.frequency,
        reminderTimes: medicine.reminderTimes,
        notes: medicine.notes,
        quantityAvailable: updatedStock,
        dosageQuantity: medicine.dosageQuantity,
        dailyConsumption: medicine.dailyConsumption,
        refillThreshold: medicine.refillThreshold,
      );
      await _medicineRepository.saveMedicine(updatedMed);
      return true;
    } catch (e) {
      debugPrint('[DASHBOARD] Mark medicine taken failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    ProfileStateManager.instance.removeListener(_onProfileStateChanged);
    _profileSub?.cancel();
    _medsSub?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }
}
