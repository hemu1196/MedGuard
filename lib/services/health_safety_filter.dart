import '../models/ai_response.dart';
import 'ai_health_service.dart';

class HealthSafetyFilter {
  static AIResponse filter({
    required String userQuery,
    required AIResponse response,
  }) {
    final lowerQuery = userQuery.toLowerCase();
    
    // 1. Red-Flag Emergency Indicators check
    bool isEmergency = response.isEmergency;
    HealthUrgency urgency = response.urgency;

    if (_containsRedFlags(lowerQuery)) {
      isEmergency = true;
      urgency = HealthUrgency.red;
    }

    // 2. Warning signs check & emergency warning insertion
    List<String> warningSigns = List<String>.from(response.warningSigns);
    if (isEmergency) {
      if (!warningSigns.any((w) => w.toLowerCase().contains('emergency'))) {
        warningSigns.insert(
          0,
          'SEEK IMMEDIATE EMERGENCY MEDICAL CARE (e.g. Call 911 or local emergency services).',
        );
      }
    }

    // 3. Medication Safeguard Check
    List<String> considerations = List<String>.from(response.considerations);
    if (_isMedicationRequest(lowerQuery)) {
      const safeguardText =
          'I can provide general health information, but medication choice and dosage should follow your doctor\'s or pharmacist\'s advice.';
      if (!considerations.any((c) => c.contains('pharmacist') || c.contains('doctor\'s or pharmacist\'s advice'))) {
        considerations.insert(0, safeguardText);
      }
    }

    // 4. Disclaimer Check
    String disclaimer = response.disclaimer;
    if (disclaimer.trim().isEmpty || !disclaimer.contains('professional medical')) {
      disclaimer =
          'This information is general health guidance and does not replace professional medical diagnosis, treatment, or evaluation. Always consult a qualified healthcare provider for personal medical advice.';
    }

    // 5. Build sanitized AIResponse
    return AIResponse(
      text: response.text,
      source: response.source,
      isFallback: response.isFallback,
      category: response.category,
      isEmergency: isEmergency,
      timestamp: response.timestamp,
      urgency: urgency,
      understanding: response.understanding,
      followUpQuestions: response.followUpQuestions,
      considerations: considerations,
      whatYouCanDoNow: response.whatYouCanDoNow,
      warningSigns: warningSigns,
      whenToSeekMedicalHelp: isEmergency
          ? 'Seek immediate emergency medical care or call local emergency services immediately.'
          : response.whenToSeekMedicalHelp,
      disclaimer: disclaimer,
      errorInfo: response.errorInfo,
    );
  }

  static bool _containsRedFlags(String lowerQuery) {
    return lowerQuery.contains('chest pain') ||
        (lowerQuery.contains('sudden') && lowerQuery.contains('vision')) ||
        lowerQuery.contains('shortness of breath') ||
        lowerQuery.contains('difficulty breathing') ||
        lowerQuery.contains('numbness') ||
        lowerQuery.contains('paralysis') ||
        lowerQuery.contains('coughing blood') ||
        lowerQuery.contains('unconscious') ||
        lowerQuery.contains('fainting') ||
        lowerQuery.contains('stroke') ||
        lowerQuery.contains('heart attack') ||
        lowerQuery.contains('severe allergic reaction') ||
        lowerQuery.contains('anaphylaxis');
  }

  static bool _isMedicationRequest(String lowerQuery) {
    return lowerQuery.contains('what medicine') ||
        lowerQuery.contains('which medicine') ||
        lowerQuery.contains('prescribe') ||
        lowerQuery.contains('what pill') ||
        lowerQuery.contains('what drug') ||
        lowerQuery.contains('dosage') ||
        lowerQuery.contains('how much dose') ||
        lowerQuery.contains('antibiotic');
  }
}
