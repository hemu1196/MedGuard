const SYSTEM_INSTRUCTION =
  'You are MedGuard AI, an intelligent clinical and digital health assistant embedded within the MEDGUARD emergency & healthcare platform. ' +
  'Provide direct, informative, educational responses tailored strictly to the user question. ' +
  'CRITICAL DIRECTIVE: DO NOT recite repetitive boilerplate self-care clichés (such as "drink plenty of water, sleep 8 hours, maintain a balanced diet, avoid stress") unless explicitly asked about general wellness routines. ' +
  'Always address the specific medical metric, medication class, symptom mechanism, first aid procedure, or MEDGUARD application feature requested. ' +
  'Do not prescribe dosages or issue diagnostic conclusions. ' +
  'If life-threatening emergencies (such as chest pain, stroke signs, severe hemorrhage, or respiratory failure) arise, instruct the user to call emergency services (108 / 112) immediately and trigger MEDGUARD SOS.';

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

const getClinicalTopicGuidance = (query) => {
  const q = query.toLowerCase();

  // 1. Body Mass Index (BMI)
  if (q.includes('bmi') || q.includes('body mass index')) {
    return (
      'Body Mass Index (BMI) is a standardized metric calculated as weight in kilograms divided by height in meters squared (kg/m²).\n\n' +
      'WHO Classification Standards:\n' +
      '• Underweight: BMI < 18.5\n' +
      '• Normal Weight: BMI 18.5 – 24.9\n' +
      '• Overweight: BMI 25.0 – 29.9\n' +
      '• Obesity (Class 1+): BMI ≥ 30.0\n\n' +
      'In MEDGUARD: You can compute your personalized BMI, review category risks, and track historical calculations directly under the Health Vault / BMI Tracker tab.'
    );
  }

  // 2. Paracetamol / Acetaminophen
  if (q.includes('paracetamol') || q.includes('acetaminophen') || q.includes('tylenol') || q.includes('crocin') || q.includes('dolo')) {
    return (
      'Paracetamol (Acetaminophen) is a widely used analgesic (pain reliever) and antipyretic (fever reducer).\n\n' +
      'Clinical Safety Guidelines:\n' +
      '• Indications: Mild-to-moderate headache, toothache, muscle aches, and fever reduction.\n' +
      '• Maximum Adult Dosage: Standard limit is 4,000 mg (4 grams) per 24 hours from all combined sources. Dosing intervals are typically 4 to 6 hours apart.\n' +
      '• Precautions: Exceeding safe thresholds carries severe risk of acute liver injury (hepatotoxicity). Avoid combining with alcohol or other medications containing acetaminophen.\n' +
      '• Consult a licensed physician or pharmacist for individualized dosing, especially for pediatric patients or individuals with liver impairment.'
    );
  }

  // 3. Ibuprofen / NSAIDs
  if (q.includes('ibuprofen') || q.includes('advil') || q.includes('nsaid') || q.includes('brufen') || q.includes('combiflam')) {
    return (
      'Ibuprofen is a Non-Steroidal Anti-Inflammatory Drug (NSAID) used to relieve pain, inflammation, and fever.\n\n' +
      'Key Information:\n' +
      '• Indications: Inflammatory joint pain, dental discomfort, menstrual cramps, and swelling.\n' +
      '• Administration: Always take with food or milk to reduce gastric irritation.\n' +
      '• Contraindications: Avoid if you have active stomach ulcers, chronic kidney disease, severe cardiac disease, or in the third trimester of pregnancy.\n' +
      '• Consult your physician or pharmacist before regular use.'
    );
  }

  // 4. Medicine Reminders / Pill Tracking in MedGuard
  if (q.includes('medicine reminder') || q.includes('reminder') || q.includes('pill tracker') || q.includes('alarm')) {
    return (
      'MEDGUARD Medicine Reminder System:\n\n' +
      '• Scheduling: Add medications with dosage, scheduled times (e.g. 08:00, 20:00), frequency, and initial stock.\n' +
      '• Actions on Alert:\n' +
      '  - TAKEN: Records exact timestamp in Medication Log and automatically deducts 1 unit from remaining stock.\n' +
      '  - SNOOZE: Delays the reminder for a short duration.\n' +
      '  - SKIP: Records reason for skipping to maintain accurate adherence records.\n' +
      '• Stock Warnings: The app alerts you when remaining stock drops low, preventing missed doses.'
    );
  }

  // 5. Emergency SOS & Contacts in MedGuard
  if (q.includes('emergency contact') || q.includes('sos') || q.includes('distress') || q.includes('emergency button')) {
    return (
      'MEDGUARD Emergency Assistance & SOS System:\n\n' +
      '• SOS Trigger: Activating the red SOS button initiates rapid emergency protocols.\n' +
      '• Automated SMS: Broadcasts an alert message with your live GPS location coordinates to your registered emergency contacts.\n' +
      '• Direct Emergency Dial: Provides immediate one-touch calling to 108 (Ambulance), 112 (National Emergency), or your primary contact.\n' +
      '• Profile Sync: Your emergency contacts and medical summary (blood group, allergies) synchronize securely with MongoDB Atlas.'
    );
  }

  // 6. Ambulance Assistance in MedGuard
  if (q.includes('ambulance') || q.includes('paramedic')) {
    return (
      'MEDGUARD Ambulance Assistance:\n\n' +
      '• Direct Dispatch: Instantly connects you to 108 Emergency Ambulance dispatch services.\n' +
      '• Geolocation Transmission: Displays your current coordinates to guide responders to your exact location.\n' +
      '• Hospital Route Integration: Allows identifying the nearest trauma-ready hospital in real time.'
    );
  }

  // 7. Nearby Hospitals & Emergency Map
  if (q.includes('hospital') || q.includes('clinic') || q.includes('map') || q.includes('nearby')) {
    return (
      'MEDGUARD Nearby Hospitals & Map Feature:\n\n' +
      '• Live Geolocation: Utilizes OpenStreetMap (OSM) to detect licensed hospitals and clinics around your location.\n' +
      '• Accurate Distance: Calculates real-time distance and estimated transit time.\n' +
      '• Facility Attributes: Displays 24/7 emergency readiness, addresses, and verified direct telephone calling links.'
    );
  }

  // 8. Health Vault / Medical Documents
  if (q.includes('vault') || q.includes('health record') || q.includes('document') || q.includes('pdf export')) {
    return (
      'MEDGUARD Health Vault:\n\n' +
      '• Storage: Securely store prescriptions, blood reports, imaging scans, and doctor consultation summaries.\n' +
      '• Formats: Supports uploaded images, documents, and notes.\n' +
      '• PDF Generation: Automatically converts clinical entries and appointment summaries into downloadable A4 PDF documents.\n' +
      '• Sharing: Share records directly with your healthcare providers via system share sheets.'
    );
  }

  // 9. Appointments & Doctor Visits
  if (q.includes('appointment') || q.includes('doctor visit') || q.includes('schedule visit')) {
    return (
      'MEDGUARD Doctor Appointments Feature:\n\n' +
      '• Booking: Schedule appointments with doctor name, specialty, clinic/hospital, date, and time.\n' +
      '• Notifications: Configure tiered alerts (1 day before, 1 hour before, 30 min before, or at visit time).\n' +
      '• Status Management: Track visits across Upcoming, Completed, and Cancelled tabs.\n' +
      '• Telephony & PDF: One-tap calling to clinic reception and downloadable appointment summary slips.'
    );
  }

  // 10. Water Intake & Daily Hydration
  if (q.includes('water') || q.includes('hydration') || q.includes('fluid')) {
    return (
      'Daily Hydration Guidance & MEDGUARD Water Tracker:\n\n' +
      '• Recommended Intake: Standard baseline is 2,000 – 2,500 mL (approx. 8–10 glasses) daily for healthy adults, adjusting for heat, exercise, and health conditions.\n' +
      '• In-App Logging: Log each glass (250 mL) in the Water Tracker to view your daily completion progress bar.\n' +
      '• Dehydration Signs: Dry mouth, dark concentrated urine, fatigue, and headache.'
    );
  }

  // 11. Blood Pressure & Hypertension
  if (q.includes('bp') || q.includes('blood pressure') || q.includes('hypertension')) {
    return (
      'Blood Pressure Categories (AHA/ACC Standards):\n\n' +
      '• Normal: Systolic < 120 mmHg AND Diastolic < 80 mmHg\n' +
      '• Elevated: Systolic 120–129 mmHg AND Diastolic < 80 mmHg\n' +
      '• Stage 1 Hypertension: Systolic 130–139 mmHg OR Diastolic 80–89 mmHg\n' +
      '• Stage 2 Hypertension: Systolic ≥ 140 mmHg OR Diastolic ≥ 90 mmHg\n' +
      '• Hypertensive Crisis: Systolic > 180 mmHg and/or Diastolic > 120 mmHg (requires immediate emergency medical evaluation).\n\n' +
      'Monitor consistently and log readings in MEDGUARD Health Vault for physician review.'
    );
  }

  // 12. Blood Sugar / Diabetes / Hypoglycemia
  if (q.includes('sugar') || q.includes('glucose') || q.includes('diabetes') || q.includes('hypoglycemia')) {
    return (
      'Blood Glucose Ranges & Diabetes Guidance:\n\n' +
      '• Fasting Blood Sugar (Normal): 70 – 99 mg/dL\n' +
      '• Fasting (Prediabetes): 100 – 125 mg/dL\n' +
      '• Fasting (Diabetes): ≥ 126 mg/dL\n' +
      '• Postprandial (2 hours post-meal): Normal < 140 mg/dL; Diabetes ≥ 200 mg/dL\n\n' +
      'HYPOGLYCEMIA WARNING (< 70 mg/dL): Symptoms include shakiness, sweating, dizziness, and rapid heartbeat. Take 15 grams of fast-acting carbohydrates (fruit juice, 3-4 glucose tablets) immediately and recheck after 15 minutes.'
    );
  }

  // 13. Burns & Scalds First Aid
  if (q.includes('burn') || q.includes('scald')) {
    return (
      'First Aid for Minor Burns:\n\n' +
      '1. Cool the Burn: Hold the affected area immediately under cool, gentle running tap water for 10 to 20 minutes.\n' +
      '2. Do NOT Apply: Never apply ice, ice water, butter, oil, or toothpaste, as these cause tissue damage and promote infection.\n' +
      '3. Protect the Area: Cover loosely with a sterile non-stick dressing or clean plastic wrap.\n' +
      '4. Red Flags: Seek emergency care immediately if the burn is chemical or electrical, affects the face/hands/groin, causes extensive blistering, or covers an area larger than the palm of your hand.'
    );
  }

  // 14. Headache / Migraine
  if (q.includes('headache') || q.includes('migraine')) {
    return (
      'Headache Assessment & Management:\n\n' +
      '• Tension vs Migraine: Tension headaches present as a dull, steady band-like ache; migraines often feature throbbing, unilateral pain accompanied by nausea or sensitivity to light and sound.\n' +
      '• Immediate Care: Rest in a cool, quiet, dimmed room. Ensure adequate hydration. Avoid prolonged smartphone and laptop screen glare.\n' +
      '• RED FLAGS: Seek urgent medical attention if the headache is sudden and explosively severe ("thunderclap"), follows head trauma, or is accompanied by stiff neck, high fever, visual loss, or limb numbness.'
    );
  }

  // 15. Fever & Temperature
  if (q.includes('fever') || q.includes('temperature') || q.includes('chills')) {
    return (
      'Fever Management Guidelines:\n\n' +
      '• Definition: A body temperature of 100.4°F (38°C) or higher is clinically recognized as fever.\n' +
      '• Care: Wear light clothing, stay hydrated with water and oral electrolyte fluids, rest adequately, and use lukewarm (not cold) sponge baths if uncomfortable.\n' +
      '• Monitoring: Record temperature readings every 4 to 6 hours.\n' +
      '• Red Flags: Consult a doctor if fever exceeds 103°F (39.4°C), lasts longer than 3 days, or is accompanied by confusion, stiff neck, shortness of breath, or an unexplained rash.'
    );
  }

  // 16. Stomach Pain & Abdominal Discomfort
  if (q.includes('stomach') || q.includes('abdomen') || q.includes('abdominal') || q.includes('cramp') || q.includes('belly')) {
    return (
      'Abdominal Discomfort Assessment:\n\n' +
      '• Common Causes: Indigestion, gas, dietary changes, mild gastroenteritis, or muscle strain.\n' +
      '• Supportive Care: Rest comfortably with knees bent to ease tension, sip warm fluids or oral rehydration solution, and eat bland items (rice, toast, bananas).\n' +
      '• RED FLAGS: Seek immediate clinical evaluation if pain is severe, sudden, localized to the right lower abdomen (appendicitis sign), or accompanied by rigid abdomen, high fever, or blood in stool or vomit.'
    );
  }

  // 17. Nausea & Vomiting
  if (q.includes('vomit') || q.includes('nausea') || q.includes('throwing up')) {
    return (
      'Nausea & Vomiting Care:\n\n' +
      '• Primary Priority: Prevention of dehydration is paramount.\n' +
      '• Protocol: Rest the stomach for 30–60 minutes after an episode. Then take small, frequent spoonfuls of water or oral rehydration salts (ORS) every 5–10 minutes.\n' +
      '• Avoid: Dairy, fried foods, caffeine, and spicy items.\n' +
      '• Red Flags: Inability to keep fluids down for over 24 hours, dark or absent urine, extreme dizziness upon standing, or vomiting dark coffee-ground material.'
    );
  }

  // 18. Cough & Cold
  if (q.includes('cough') || q.includes('cold') || q.includes('congestion') || q.includes('runny nose')) {
    return (
      'Cough & Upper Respiratory Symptoms:\n\n' +
      '• Nature: Most common colds and coughs are viral, resolving spontaneously within 7 to 10 days.\n' +
      '• Relief Measures: Warm steam inhalation, warm honey-lemon water (for individuals over 1 year), saline nasal sprays, and ample rest.\n' +
      '• Warning Signs: Consult a healthcare professional if cough persists beyond 2–3 weeks, produces blood or thick rusty sputum, or is accompanied by chest tightness or breathing difficulty.'
    );
  }

  // 19. Sore Throat
  if (q.includes('throat') || q.includes('pharyngitis') || q.includes('swallowing')) {
    return (
      'Sore Throat Relief:\n\n' +
      '• Home Measures: Gargle with warm salt water (1/2 teaspoon salt in 1 cup warm water) 3–4 times daily; drink warm teas with honey; use throat lozenges.\n' +
      '• Warning Signs: Inability to swallow fluids, difficulty opening the mouth, breathing difficulty, or visible white patches on tonsils with high fever require clinical examination.'
    );
  }

  // 20. Dizziness & Vertigo
  if (q.includes('dizzy') || q.includes('dizziness') || q.includes('vertigo') || q.includes('lightheaded')) {
    return (
      'Dizziness & Balance Guidance:\n\n' +
      '• Safety First: Sit or lie down immediately in a safe position to prevent falls or head injury.\n' +
      '• Causes: Dehydration, orthostatic hypotension (standing too rapidly), inner ear conditions (BPPV), low blood sugar, or fatigue.\n' +
      '• Red Flags: Seek emergency care if dizziness occurs alongside chest pain, heart palpitations, facial numbness, weakness in an arm/leg, or slurred speech.'
    );
  }

  // 21. Back & Muscle Pain
  if (q.includes('back pain') || q.includes('muscle pain') || q.includes('strain') || q.includes('lumbar')) {
    return (
      'Back Pain & Muscle Strain:\n\n' +
      '• Acute Care: Apply cold compresses for the first 24–48 hours to minimize inflammation, followed by gentle heat. Avoid strict bed rest; gentle walking promotes recovery.\n' +
      '• Red Flags: Seek immediate emergency assessment if back pain is accompanied by loss of bowel or bladder control, numbness in the groin/saddle area, or progressive leg weakness.'
    );
  }

  // 22. Allergies & Anaphylaxis
  if (q.includes('allergy') || q.includes('allergic') || q.includes('hives') || q.includes('rash')) {
    return (
      'Allergy Guidance:\n\n' +
      '• Mild Reactions: Localized itching, sneezing, or hives often respond to over-the-counter antihistamines and allergen avoidance.\n' +
      '• SEVERE ANAPHYLAXIS ALERT: Swelling of the lips, tongue, throat tightness, wheezing, or difficulty breathing is a medical emergency. Administer an epinephrine auto-injector if available, call 108/112 immediately, and trigger MEDGUARD SOS.'
    );
  }

  // 23. General Medication Safety
  if (q.includes('medicine') || q.includes('dosage') || q.includes('pill') || q.includes('drug') || q.includes('antibiotic')) {
    return (
      'Medication Safety Standards:\n\n' +
      '• Always take prescription drugs strictly according to the prescribing physician\'s dosage and schedule.\n' +
      '• Complete full antibiotic courses unless instructed otherwise by your doctor to prevent antibiotic resistance.\n' +
      '• Never combine medications without verifying drug-drug interactions with a pharmacist.\n' +
      '• Track all prescribed medications and dosages in the MEDGUARD Medicines tab.'
    );
  }

  // 24. First Aid
  if (q.includes('first aid') || q.includes('wound') || q.includes('cut') || q.includes('bleeding')) {
    return (
      'First Aid & Wound Management:\n\n' +
      '• Minor Wounds: Apply direct pressure with a clean cloth to stop bleeding. Rinse thoroughly under clean tap water. Apply antiseptic and dress with a sterile bandage.\n' +
      '• Tetanus & Suture Red Flags: Wounds from rusted or dirty objects, puncture wounds, or deep gaping lacerations require clinical irrigation, suturing, and tetanus booster evaluation within 24 hours.'
    );
  }

  // Default Clinical Fallback
  return (
    `Regarding your inquiry on "${query}":\n\n` +
    'MEDGUARD Clinical Guidance:\n' +
    '• For symptoms or health concerns, monitor their onset, intensity, and any related triggers.\n' +
    '• Maintain a log of observed vitals (such as temperature, pulse, or blood pressure) in your MEDGUARD Health Vault to provide accurate context for your healthcare provider.\n' +
    '• If your symptoms are persistent, worsening, or causing concern, schedule an appointment with a licensed physician or specialist.\n' +
    '• For sudden, severe, or life-threatening symptoms, immediately contact emergency services (108 / 112) or trigger MEDGUARD SOS.'
  );
};

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

    // 1. Triage critical life-threatening conditions immediately
    if (
      lower.includes('chest pain') ||
      lower.includes('heart attack') ||
      lower.includes('cannot breathe') ||
      lower.includes('difficulty breathing') ||
      lower.includes('cant breathe') ||
      lower.includes('unconscious') ||
      lower.includes('stroke') ||
      lower.includes('severe bleeding') ||
      lower.includes('blue lips') ||
      lower.includes('choking')
    ) {
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
      reply = getClinicalTopicGuidance(message);
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
