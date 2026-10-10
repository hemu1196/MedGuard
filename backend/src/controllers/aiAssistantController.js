const chat = async (req, res) => {
  try {
    const { message, context } = req.body;

    if (!message) {
      return res.status(400).json({
        success: false,
        message: 'Message is required.',
      });
    }

    const lower = message.toLowerCase();
    let reply = '';
    let isEmergency = false;

    if (
      lower.includes('chest pain') ||
      lower.includes('heart attack') ||
      lower.includes('cannot breathe') ||
      lower.includes('unconscious') ||
      lower.includes('stroke') ||
      lower.includes('severe bleeding')
    ) {
      isEmergency = true;
      reply = 'CRITICAL ALERT: Your query mentions severe emergency symptoms. Please call local emergency medical services immediately or trigger the MEDGUARD SOS button!';
    } else if (lower.includes('headache') || lower.includes('fever')) {
      reply = 'For fever or headache: Stay hydrated, rest, and monitor your body temperature. If symptoms persist for more than 48 hours or worsen, consult a medical professional.';
    } else if (lower.includes('medicine') || lower.includes('dosage') || lower.includes('pill')) {
      reply = 'Always follow your physician\'s dosage instructions. You can view and manage your scheduled medications in the MEDGUARD Medicines tab.';
    } else {
      reply = `Thank you for consulting MEDGUARD AI Assistant. Regarding "${message}": Ensure adequate hydration, balanced nutrition, and appropriate rest. If symptoms worsen, please schedule an appointment or visit a doctor.`;
    }

    return res.status(200).json({
      success: true,
      reply,
      isEmergency,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to process AI chat request.',
    });
  }
};

const assessHealthRisk = async (req, res) => {
  try {
    const { symptoms, age, systolicBp, diastolicBp, heartRate, bloodSugar } = req.body;

    let riskLevel = 'Low';
    let riskScore = 15;
    const recommendations = [];

    if (systolicBp > 140 || diastolicBp > 90) {
      riskLevel = 'Moderate';
      riskScore += 30;
      recommendations.push('Elevated blood pressure detected. Reduce sodium intake and monitor daily.');
    }

    if (bloodSugar > 140) {
      if (riskLevel === 'Low') riskLevel = 'Moderate';
      riskScore += 25;
      recommendations.push('Elevated blood sugar detected. Consult your physician regarding diabetes screening.');
    }

    if (Array.isArray(symptoms) && symptoms.some((s) => ['chest pain', 'shortness of breath', 'dizziness'].includes(s.toLowerCase()))) {
      riskLevel = 'High';
      riskScore += 40;
      recommendations.push('High-risk symptoms reported. Seek immediate clinical evaluation.');
    }

    if (recommendations.length === 0) {
      recommendations.push('Vitals appear within normal ranges. Maintain regular physical activity and wellness routines.');
    }

    return res.status(200).json({
      success: true,
      riskLevel,
      riskScore: Math.min(riskScore, 100),
      recommendations,
      assessedAt: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to perform health risk assessment.',
    });
  }
};

module.exports = {
  chat,
  assessHealthRisk,
};
