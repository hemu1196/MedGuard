const SYSTEM_INSTRUCTION =
  'You are MedGuard AI, a professional medical and health guidance assistant. ' +
  'Provide educational, non-diagnostic health guidance. ' +
  'Do not prescribe medication or invent dosages. ' +
  'Advise the user to consult a licensed physician or specialist for diagnosis and treatment. ' +
  'If life-threatening symptoms are mentioned, immediately advise calling local emergency services (such as 108 or 112).';

const CANDIDATE_MODELS = ['gemini-1.5-flash', 'gemini-2.0-flash', 'gemini-1.5-pro', 'gemini-pro'];

/**
 * Executes a call to Google Gemini Generative Language API using server-side GEMINI_API_KEY
 */
async function callGeminiApi(prompt, history = []) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey || apiKey.trim().length === 0) {
    return null;
  }

  for (const model of CANDIDATE_MODELS) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey.trim()}`;

      const contents = [];
      if (Array.isArray(history)) {
        for (const item of history) {
          if (item && item.text) {
            contents.push({
              role: item.isUser ? 'user' : 'model',
              parts: [{ text: item.text }],
            });
          }
        }
      }

      contents.push({
        role: 'user',
        parts: [{ text: `${SYSTEM_INSTRUCTION}\n\nUser Question: ${prompt}` }],
      });

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ contents }),
        signal: AbortSignal.timeout(10000),
      });

      if (response.ok) {
        const data = await response.json();
        const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
        if (text && text.trim().length > 0) {
          return text.trim();
        }
      }
    } catch (err) {
      // Gracefully continue to next candidate model
    }
  }

  return null;
}

const chat = async (req, res) => {
  try {
    const rawMessage = req.body.message || req.body.prompt;
    const history = req.body.history || [];

    if (!rawMessage || typeof rawMessage !== 'string' || rawMessage.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'A valid non-empty message is required.',
      });
    }

    const message = rawMessage.trim().slice(0, 2000);
    const lower = message.toLowerCase();
    let isEmergency = false;

    // 1. Triage critical life-threatening conditions immediately
    if (
      lower.includes('chest pain') ||
      lower.includes('heart attack') ||
      lower.includes('cannot breathe') ||
      lower.includes('difficulty breathing') ||
      lower.includes('unconscious') ||
      lower.includes('stroke') ||
      lower.includes('severe bleeding') ||
      lower.includes('blue lips') ||
      lower.includes('choking')
    ) {
      isEmergency = true;
      return res.status(200).json({
        success: true,
        reply:
          'CRITICAL ALERT: Your query reports severe or life-threatening symptoms. ' +
          'Please call emergency medical services immediately (108 in India, or 112) or trigger the MEDGUARD SOS button in the app. ' +
          'Do not wait for online guidance.',
        isEmergency: true,
        source: 'clinical_emergency_triage',
        timestamp: new Date().toISOString(),
      });
    }

    // 2. Attempt Google Gemini using server-side secret
    let reply = await callGeminiApi(message, history);
    let source = 'gemini_cloud';

    // 3. Clinical informational fallback if Gemini key is absent or cloud call failed
    if (!reply) {
      source = 'clinical_fallback_engine';
      if (lower.includes('headache') || lower.includes('migraine')) {
        reply =
          'Regarding headaches: Common causes include tension, dehydration, eye strain, or lack of sleep. ' +
          'Rest in a quiet, dark room, hydrate adequately, and avoid excessive screen time. ' +
          'If accompanied by sudden onset, stiff neck, high fever, or neurological symptoms, seek urgent medical evaluation.';
      } else if (lower.includes('fever') || lower.includes('temperature')) {
        reply =
          'Regarding fever: Stay well-hydrated with water and oral electrolytes, rest adequately, and monitor your temperature periodically. ' +
          'Wear lightweight clothing and avoid heavy blankets. If temperature exceeds 103°F (39.4°C), persists beyond 48–72 hours, or is accompanied by confusion or rash, consult a doctor immediately.';
      } else if (lower.includes('medicine') || lower.includes('dosage') || lower.includes('pill') || lower.includes('antibiotic')) {
        reply =
          'Regarding medications: Always take medications exactly as prescribed by your treating physician. ' +
          'Do not alter dosages, discontinue antibiotics prematurely, or self-prescribe. ' +
          'You can track your medication schedule in the MEDGUARD Medicines tab.';
      } else if (lower.includes('stomach') || lower.includes('abdomen') || lower.includes('nausea') || lower.includes('vomiting')) {
        reply =
          'Regarding digestive discomfort: Sip clear fluids slowly, avoid heavy or spicy foods, and eat bland items (such as rice or bananas) as tolerated. ' +
          'Seek urgent clinical care if you notice intense abdominal pain, blood in vomit or stool, or persistent inability to keep liquids down.';
      } else if (lower.includes('bp') || lower.includes('blood pressure') || lower.includes('hypertension')) {
        reply =
          'Regarding blood pressure: Maintain low sodium intake, manage stress, engage in light aerobic activity, and track vitals regularly in MEDGUARD Health Vault. ' +
          'Values consistently above 140/90 mmHg warrant physician review.';
      } else {
        reply =
          `Thank you for consulting MEDGUARD AI Assistant regarding "${message}". ` +
          'For optimal health, ensure balanced nutrition, adequate hydration, regular activity, and sufficient restorative sleep. ' +
          'Please consult a licensed medical professional for an accurate diagnosis and personalized treatment plan.';
      }
    }

    return res.status(200).json({
      success: true,
      reply,
      isEmergency: false,
      source,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to process AI chat request: ' + error.message,
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
      message: 'Failed to perform health risk assessment: ' + error.message,
    });
  }
};

module.exports = {
  chat,
  assessHealthRisk,
};
