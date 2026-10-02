import 'package:flutter/material.dart';
import 'auth_gate.dart';
import 'routes.dart';
import 'theme.dart';
import '../screens/auth/login_page.dart';
import '../screens/onboarding/health_profile_page.dart';
import '../screens/main_navigation_frame.dart';
import '../screens/medicines/medicine_page.dart';
import '../screens/hospitals/nearby_hospitals_page.dart';
import '../screens/ambulance/ambulance_assistance_page.dart';
import '../screens/emergency/emergency_sos_page.dart';
import '../screens/maps/explore_map_page.dart';
import '../screens/settings/settings_page.dart';

// Blueprint Feature Screens
import '../screens/risk/health_risk_prediction_page.dart';
import '../screens/qr/qr_medical_profile_page.dart';
import '../screens/family/family_health_dashboard_page.dart';
import '../screens/emergency/offline_emergency_page.dart';
import '../screens/emergency/fall_detection_settings_page.dart';
import '../screens/medicines/medicine_verification_page.dart';
import '../screens/wellness/water_intake_page.dart';

// Working Add-On Screens
import '../screens/addons/ai_report_summary_page.dart';
import '../screens/addons/appointments_page.dart';
import '../screens/addons/diet_fitness_page.dart';
import '../screens/addons/mental_wellness_page.dart';
import '../screens/addons/health_analytics_page.dart';

class MedGuardApp extends StatelessWidget {
  const MedGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEDGUARD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.profileSetup: (context) => const HealthProfilePage(),
        AppRoutes.dashboard: (context) =>
            const MainNavigationFrame(initialIndex: 0),
        AppRoutes.ai: (context) => const MainNavigationFrame(initialIndex: 1),
        AppRoutes.medicines: (context) => const MedicinePage(),
        AppRoutes.prescription: (context) => const AppointmentsPage(),
        AppRoutes.vault: (context) =>
            const MainNavigationFrame(initialIndex: 2),
        AppRoutes.hospitals: (context) => const NearbyHospitalsPage(),
        AppRoutes.ambulance: (context) => const AmbulanceAssistancePage(),
        AppRoutes.map: (context) => const ExploreMapPage(),
        AppRoutes.emergency: (context) => const EmergencySosPage(),
        AppRoutes.profile: (context) =>
            const MainNavigationFrame(initialIndex: 4),
        AppRoutes.settings: (context) => const SettingsPage(),

        // Blueprint Feature Routes
        AppRoutes.healthRisk: (context) => const HealthRiskPredictionPage(),
        AppRoutes.qrProfile: (context) => const QrMedicalProfilePage(),
        AppRoutes.familyDashboard: (context) =>
            const FamilyHealthDashboardPage(),
        AppRoutes.offlineEmergency: (context) => const OfflineEmergencyPage(),
        AppRoutes.fallDetection: (context) => const FallDetectionSettingsPage(),
        AppRoutes.medicineVerification: (context) =>
            const MedicineVerificationPage(),
        AppRoutes.waterIntake: (context) => const WaterIntakePage(),

        // Working Add-On Routes
        AppRoutes.aiReportSummary: (context) => const AiReportSummaryPage(),
        AppRoutes.appointments: (context) => const AppointmentsPage(),
        AppRoutes.dietFitness: (context) => const DietFitnessPage(),
        AppRoutes.mentalWellness: (context) => const MentalWellnessPage(),
        AppRoutes.healthAnalytics: (context) => const HealthAnalyticsPage(),
      },
    );
  }
}
