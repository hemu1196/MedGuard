import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/bmi_calculator.dart';
import '../models/health_record.dart';
import '../models/hospital.dart';
import '../models/medicine.dart';
import '../models/selected_location.dart';
import '../models/user_profile.dart';
import '../repositories/auth_repository.dart';
import '../repositories/health_record_repository.dart';
import '../repositories/medicine_repository.dart';
import '../repositories/profile_repository.dart';
import '../services/hospital_service.dart';
import '../services/location_service.dart';

class DashboardController extends ChangeNotifier {
  final AuthRepository _authRepository = AuthRepository();
  final ProfileRepository _profileRepository = ProfileRepository();
  final MedicineRepository _medicineRepository = MedicineRepository();
  final HealthRecordRepository _healthRecordRepository = HealthRecordRepository();
  final HospitalService _hospitalService = HospitalService();
  final LocationService _locationService = LocationService();

  UserProfile? userProfile;
  List<HealthRecord> healthRecords = [];
  List<Medicine> medicines = [];
  List<Hospital> nearbyHospitals = [];

  bool isLoadingProfile = true;
  bool isLoadingMedicines = true;
  bool isLoadingRecords = true;
  bool isLoadingHospitals = true;

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
    init();
  }

  Future<void> init() async {
    try {
      final userId = await _authRepository.getCurrentUserId();
      _subscribeToRealtimeData(userId);
      await loadHospitals();
    } catch (e) {
      debugPrint('[DASHBOARD CONTROLLER] Init error: $e');
      isLoadingProfile = false;
      isLoadingMedicines = false;
      isLoadingRecords = false;
      isLoadingHospitals = false;
      profileError = e.toString();
      notifyListeners();
    }
  }

  void _subscribeToRealtimeData(String userId) {
    isLoadingProfile = true;
    isLoadingMedicines = true;
    isLoadingRecords = true;
    notifyListeners();

    // 1. Profile Stream
    _profileSub?.cancel();
    _profileSub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('profile')
        .doc('main')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        userProfile = UserProfile.fromMap(doc.data()!);
        profileError = null;
      } else {
        // Fallback to repository cache
        _loadProfileFallback(userId);
      }
      isLoadingProfile = false;
      notifyListeners();
    }, onError: (e) {
      debugPrint('[DASHBOARD] Profile stream error: $e');
      _loadProfileFallback(userId);
    });

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

  Future<void> _loadProfileFallback(String userId) async {
    try {
      userProfile = await _profileRepository.getProfile(userId: userId);
    } catch (e) {
      profileError = 'Failed to load profile';
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
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
      final SelectedLocation loc = await _locationService.ensureLocationLoaded();
      currentCity = loc.displayTitle;
      final result = await _hospitalService.searchHospitalsForLocation(loc);
      nearbyHospitals = result.hospitals;
    } catch (e) {
      debugPrint('[DASHBOARD] Hospital fetch error: $e');
      hospitalsError = 'Unable to load nearby healthcare facilities.';
    } finally {
      isLoadingHospitals = false;
      notifyListeners();
    }
  }

  String get greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String get firstName {
    if (userProfile == null || userProfile!.name.trim().isEmpty) {
      final email = FirebaseAuth.instance.currentUser?.email;
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
      return 'User';
    }
    return userProfile!.name.trim().split(' ').first;
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
    _profileSub?.cancel();
    _medsSub?.cancel();
    _recordsSub?.cancel();
    super.dispose();
  }
}
