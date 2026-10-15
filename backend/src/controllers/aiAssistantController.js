/**
 * MEDGUARD AI Assistant Controller
 * Provides clinical intelligence, symptom assessment, doctor recommendations,
 * and emergency triage powered by Google Gemini with safe offline clinical fallback.
 */

const SYSTEM_INSTRUCTION =
  'You are MedGuard AI, an intelligent clinical and digital health assistant embedded within the MEDGUARD emergency & healthcare platform. ' +
  'Directly answer the user inquiry with relevant, accurate, and empathetic medical or application information. ' +
  'INTENT RULES:\n' +
  '1. GREETING ("hi", "hello", "hey"): Respond with a friendly, welcoming greeting explaining what you can do. DO NOT provide self-care advice or doctor recommendations for greetings.\n' +
  '2. APP HELP: Explain MEDGUARD features (medicine reminders, health vault, appointments, emergency SOS, ambulance, water tracker, nearby hospitals).\n' +
  '3. EDUCATION ("what is BMI", "blood pressure ranges"): Provide clear educational explanations, formulas, and ranges without unrelated self-care clichés.\n' +
  '4. MEDICINE: Provide usage, safety cautions, and liver/kidney considerations without prescribing dosages.\n' +
  '5. SYMPTOMS: Provide a structured response with: (a) Understanding, (b) Possible considerations, (c) Safe self-care precautions, (d) Recommended doctor/specialist type with urgency and reason, (e) Red-flag warning signs, and (f) 1-2 focused follow-up questions.\n' +
  '6. EMERGENCY: For chest pain, stroke signs, difficulty breathing, or severe bleeding, advise immediate 108/112/911 emergency care.\n' +
  'Output strictly valid JSON with keys: "intent", "reply", "recommendedCare" (or null), "warningSigns", "followUpQuestions".';

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
          // Attempt JSON parsing
          try {
            const jsonStart = text.indexOf('{');
            const jsonEnd = text.lastIndexOf('}');
            if (jsonStart !== -1 && jsonEnd !== -1) {
              const parsed = JSON.parse(text.substring(jsonStart, jsonEnd + 1));
              return {
                intent: parsed.intent || 'general',
                reply: parsed.reply || text.trim(),
                recommendedCare: parsed.recommendedCare || null,
                warningSigns: Array.isArray(parsed.warningSigns) ? parsed.warningSigns : [],
                followUpQuestions: Array.isArray(parsed.followUpQuestions) ? parsed.followUpQuestions : [],
                isEmergency: parsed.intent === 'emergency',
              };
            }
          } catch (e) {
            // Text fallback
          }

          return {
            intent: 'general',
            reply: text.trim(),
            recommendedCare: null,
            warningSigns: [],
            followUpQuestions: [],
            isEmergency: false,
          };
        }
      }
    } catch (err) {
      // Gracefully continue to next candidate model
    }
  }

  return null;
}

function normalizeQuery(str) {
  return str
    .toLowerCase()
    .trim()
    .replace(/[^\w\s]/g, '')
    .replace(/\s+/g, ' ');
}

function isGreetingQuery(norm) {
  const greetings = [
    'hi',
    'hello',
    'hey',
    'greetings',
    'howdy',
    'sup',
    'good morning',
    'good afternoon',
    'good evening',
    'how are you',
    'who are you',
    'what are you',
    'help',
    'help me',
  ];
  return (
    greetings.includes(norm) ||
    norm.startsWith('hi ') ||
    norm.startsWith('hello ') ||
    norm.startsWith('hey ')
  );
}

function isEmergencyQuery(norm) {
  const redFlags = [
    'chest pain',
    'heart attack',
    'cannot breathe',
    'cant breathe',
    'difficulty breathing',
    'shortness of breath',
    'unconscious',
    'passed out',
    'stroke',
    'facial drooping',
    'slurred speech',
    'severe bleeding',
    'coughing blood',
    'blue lips',
    'choking',
    'anaphylaxis',
    'severe allergic reaction',
  ];
  return redFlags.some((rf) => norm.includes(rf));
}

/**
 * Intelligent clinical and app-guidance fallback engine
 */
const getClinicalTopicGuidance = (query) => {
  const norm = normalizeQuery(query);

  // 1. GREETING
  if (isGreetingQuery(norm)) {
    return {
      intent: 'greeting',
      reply:
        "Hello! I am MEDGUARD AI, your personal intelligent health companion.\n\n" +
        "I can help you understand medical topics, medication guidelines, analyze symptoms, or explain MEDGUARD features like medicine reminders and emergency assistance.\n\n" +
        "What would you like to know today?",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: [
        'What is BMI?',
        'What is paracetamol used for?',
        'How do medicine reminders work?',
        'I have a headache',
      ],
      isEmergency: false,
    };
  }

  // 2. BODY MASS INDEX (BMI)
  if (norm.includes('bmi') || norm.includes('body mass index')) {
    return {
      intent: 'education',
      reply:
        "**Body Mass Index (BMI)** is a standard clinical screening metric that evaluates body weight relative to height (kg/m²).\n\n" +
        "**Standard Classifications:**\n" +
        "• Underweight: BMI < 18.5\n" +
        "• Normal weight: BMI 18.5 – 24.9\n" +
        "• Overweight: BMI 25.0 – 29.9\n" +
        "• Obesity: BMI ≥ 30.0\n\n" +
        "**How to calculate:** Weight in kilograms divided by the square of height in meters (e.g. 70 kg ÷ (1.75 m × 1.75 m) = 22.9).\n\n" +
        "In MEDGUARD, you can compute and track your BMI under the **Health Vault / Profile** tab.",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: [
        'How do I update my height and weight in profile?',
        'What is a healthy target BMI?',
      ],
      isEmergency: false,
    };
  }

  // 3. PARACETAMOL / ACETAMINOPHEN
  if (
    norm.includes('paracetamol') ||
    norm.includes('acetaminophen') ||
    norm.includes('crocin') ||
    norm.includes('dolo') ||
    norm.includes('tylenol')
  ) {
    return {
      intent: 'medicine',
      reply:
        "**Paracetamol (Acetaminophen)** is a common analgesic (pain reliever) and antipyretic (fever reducer).\n\n" +
        "**Key Information:**\n" +
        "• **Indications:** Mild-to-moderate headache, muscle aches, toothache, and fever management.\n" +
        "• **Safety limits:** Standard adult maximum is 4,000 mg (4 grams) in 24 hours from all combined sources. Typical single dose is 500–1000 mg every 4–6 hours as needed.\n" +
        "• **Crucial precaution:** Exceeding recommended doses causes severe liver injury (hepatotoxicity). Never consume alcohol with paracetamol or take multiple medications containing acetaminophen simultaneously.\n" +
        "• Consult a licensed physician or pharmacist for personalized dosage, especially for children or patients with liver or kidney disease.",
      recommendedCare: null,
      warningSigns: [
        'Nausea, upper right abdominal pain, or jaundice (signs of liver strain).',
        'Allergic swelling, hives, or breathing difficulty.',
      ],
      followUpQuestions: [
        'Can I take paracetamol with ibuprofen?',
        'How do I log this medicine in my MEDGUARD reminders?',
      ],
      isEmergency: false,
    };
  }

  // 4. IBUPROFEN / NSAIDs
  if (
    norm.includes('ibuprofen') ||
    norm.includes('advil') ||
    norm.includes('nsaid') ||
    norm.includes('brufen') ||
    norm.includes('combiflam')
  ) {
    return {
      intent: 'medicine',
      reply:
        "**Ibuprofen** is a Non-Steroidal Anti-Inflammatory Drug (NSAID) used to relieve pain, swelling, and fever.\n\n" +
        "**Key Information:**\n" +
        "• **Indications:** Inflammatory pain, joint discomfort, dental pain, and menstrual cramps.\n" +
        "• **Administration:** Always take with food or milk to protect the stomach lining.\n" +
        "• **Contraindications:** Avoid if you have active peptic ulcers, chronic kidney disease, severe heart failure, or are in the third trimester of pregnancy.\n" +
        "• Always consult your doctor or pharmacist before regular use.",
      recommendedCare: null,
      warningSigns: ['Severe stomach pain, black tarry stools, or persistent vomiting.'],
      followUpQuestions: ['What are alternatives to ibuprofen for pain relief?'],
      isEmergency: false,
    };
  }

  // 5. ANTIBIOTICS
  if (norm.includes('antibiotic') || norm.includes('amoxicillin') || norm.includes('azithromycin')) {
    return {
      intent: 'medicine',
      reply:
        "**Antibiotic Safety Guidelines:**\n\n" +
        "• Antibiotics only treat bacterial infections; they are completely ineffective against viral infections such as colds, flu, and most sore throats.\n" +
        "• Take strictly as prescribed by a licensed doctor. Always finish the entire prescribed course even if symptoms improve, to prevent antibiotic resistance.\n" +
        "• Never share or save leftover antibiotics.",
      recommendedCare: null,
      warningSigns: ['Severe allergic reaction (wheezing, facial swelling) or watery diarrhea.'],
      followUpQuestions: ['Should I take antibiotics for a cold or sore throat?'],
      isEmergency: false,
    };
  }

  // 6. APP HELP: MEDICINE REMINDERS
  if (norm.includes('reminder') || norm.includes('pill tracker') || norm.includes('medicines')) {
    return {
      intent: 'app_help',
      reply:
        "**MEDGUARD Medicine Reminders:**\n\n" +
        "• **Setup:** Open the **Medicines** tab to add prescriptions, dosages, time schedules (e.g. 08:00, 20:00), and remaining stock quantity.\n" +
        "• **On Alert:**\n" +
        "  - **Taken:** Confirms the dose, logs timestamp in your adherence record, and deducts 1 unit from remaining stock.\n" +
        "  - **Snooze:** Snoozes reminder for 10 minutes.\n" +
        "  - **Skip:** Records the reason to maintain an accurate health log.\n" +
        "• **Stock Alerts:** The app notifies you when remaining pills reach your refill threshold.",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: ['How do I view my medication adherence history?'],
      isEmergency: false,
    };
  }

  // 7. APP HELP: HEALTH VAULT
  if (norm.includes('vault') || norm.includes('health record') || norm.includes('document')) {
    return {
      intent: 'app_help',
      reply:
        "**MEDGUARD Health Vault:**\n\n" +
        "• **Storage:** Securely store prescriptions, lab reports, imaging scans, and vaccination records in MongoDB Atlas.\n" +
        "• **PDF Download & Share:** Export complete health summaries or individual records to clean A4 PDF documents for doctor appointments.\n" +
        "• **Privacy:** All files are strictly isolated to your authenticated account.",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: ['How do I upload a prescription image to Health Vault?'],
      isEmergency: false,
    };
  }

  // 8. APP HELP: EMERGENCY SOS
  if (norm.includes('sos') || norm.includes('emergency contact') || norm.includes('ambulance')) {
    return {
      intent: 'app_help',
      reply:
        "**MEDGUARD Emergency Assistance & SOS:**\n\n" +
        "• **Emergency SOS:** Tap the red SOS card on the Dashboard to broadcast an automated emergency SMS with your live GPS location to your registered emergency contacts.\n" +
        "• **Direct Calling:** Features one-touch calling to 108 (Ambulance) or 112 (National Emergency).\n" +
        "• **Hospital Routing:** Guides emergency services and loved ones directly to your current location.",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: ['How do I update my emergency contacts list?'],
      isEmergency: false,
    };
  }

  // 9. APP HELP: WATER INTAKE
  if (norm.includes('water') || norm.includes('hydration')) {
    return {
      intent: 'app_help',
      reply:
        "**MEDGUARD Daily Water Tracker:**\n\n" +
        "• **Daily Target:** Standard healthy baseline is 2,000–2,500 mL (8–10 glasses).\n" +
        "• **Logging:** Tap **Water Intake** on the Dashboard to log glasses (+250 mL) throughout the day.\n" +
        "• **Sync:** Progress synchronizes securely with your daily health metrics.",
      recommendedCare: null,
      warningSigns: [],
      followUpQuestions: ['How do I customize my daily water target?'],
      isEmergency: false,
    };
  }

  // 10. SYMPTOM: HEADACHE
  if (norm.includes('headache') || norm.includes('migraine')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You mentioned experiencing a headache.\n\n" +
        "**Possible Considerations:**\n" +
        "• Common causes include tension (stress, prolonged screen time), dehydration, poor sleep, or migraine.\n" +
        "• Sinus congestion or neck muscle tightness can also cause radiating head pain.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Rest in a quiet, dimly lit room and practice gentle neck stretches.\n" +
        "• Drink a glass of water and stay hydrated.\n" +
        "• Apply a cool cloth to your forehead or a warm compress to the back of your neck.\n" +
        "• Avoid prolonged screen exposure and loud noises.",
      recommendedCare: {
        clinicianType: 'General Physician / Primary-Care Doctor',
        urgency: 'routine',
        urgencyLabel: 'Routine Medical Evaluation',
        reason: 'To evaluate headache patterns, rule out secondary causes, or formulate a migraine treatment plan if recurrent.',
      },
      warningSigns: [
        'Sudden, explosively severe "thunderclap" headache.',
        'Headache accompanied by fever, stiff neck, confusion, or visual loss.',
        'New headache following a head injury or accompanied by limb weakness.',
      ],
      followUpQuestions: [
        'Is the headache throbbing on one side or a dull band around your head?',
        'How long have you had this headache?',
      ],
      isEmergency: false,
    };
  }

  // 11. SYMPTOM: FEVER
  if (norm.includes('fever') || norm.includes('chills') || norm.includes('temperature')) {
    const isProlonged = norm.includes('three days') || norm.includes('3 days') || norm.includes('week');
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You reported having a fever.\n\n" +
        "**Possible Considerations:**\n" +
        "• Fever is a natural immune response to viral or bacterial infections.\n" +
        "• Viral upper respiratory infections, gastroenteritis, or urinary infections are common causes.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Drink plenty of fluids (water, oral rehydration solutions, clear broths) to replace lost electrolytes.\n" +
        "• Rest adequately in a comfortable, well-ventilated room wearing light clothing.\n" +
        "• Use lukewarm sponge baths if feeling uncomfortable (avoid ice baths).\n" +
        "• Monitor and log your temperature every 4 to 6 hours in MEDGUARD Health Vault.",
      recommendedCare: {
        clinicianType: 'General Physician / Primary-Care Doctor',
        urgency: isProlonged ? 'prompt' : 'routine',
        urgencyLabel: isProlonged ? 'Prompt Medical Attention Advised' : 'Routine Medical Evaluation',
        reason: isProlonged
          ? 'Fever persisting for 3 or more days requires clinical evaluation and blood work to identify bacterial or atypical causes.'
          : 'To evaluate the infection source if fever does not respond to supportive care within 48 hours.',
      },
      warningSigns: [
        'Temperature exceeding 103°F (39.4°C) or not responding to antipyretics.',
        'Stiff neck, severe headache, confusion, or extreme lethargy.',
        'Difficulty breathing or rapid unexplained rash.',
      ],
      followUpQuestions: [
        'What is your current temperature reading?',
        'Do you have other symptoms such as cough, sore throat, or body aches?',
      ],
      isEmergency: false,
    };
  }

  // 12. SYMPTOM: TOOTHACHE / DENTAL PAIN
  if (norm.includes('tooth') || norm.includes('teeth') || norm.includes('dental') || norm.includes('gum')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You mentioned having a toothache or dental discomfort.\n\n" +
        "**Possible Considerations:**\n" +
        "• Common causes include dental caries (cavities), pulp inflammation, gum infection (gingivitis), or wisdom tooth eruption.\n" +
        "• Temperature sensitivity (hot/cold) often suggests enamel wear or nerve involvement.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Rinse gently with warm salt water (1/2 tsp salt in warm water) after meals.\n" +
        "• Avoid very hot, cold, acidic, or hard foods.\n" +
        "• Avoid placing aspirin directly on the gum tissue as it causes chemical burns.",
      recommendedCare: {
        clinicianType: 'Dentist / Dental Surgeon',
        urgency: 'routine',
        urgencyLabel: 'Dental Examination Recommended',
        reason: 'Toothaches require professional dental examination, vitality testing, and possible radiography to treat the root cause.',
      },
      warningSigns: [
        'Visible facial or jaw swelling, or swelling extending towards the neck.',
        'Difficulty swallowing liquids or breathing.',
        'High fever accompanying dental pain.',
      ],
      followUpQuestions: [
        'Is the pain constant or triggered by hot, cold, or chewing?',
        'Do you notice any swelling in your gums or cheek?',
      ],
      isEmergency: false,
    };
  }

  // 13. SYMPTOM: SKIN RASH / DERMATITIS
  if (norm.includes('rash') || norm.includes('itch') || norm.includes('skin') || norm.includes('hives')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You reported having a skin rash or itching.\n\n" +
        "**Possible Considerations:**\n" +
        "• Common causes include contact dermatitis (soaps, lotions, plants), heat rash, allergic urticaria, eczema, or viral exanthems.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Wash gently with lukewarm water and a mild fragrance-free cleanser.\n" +
        "• Avoid scratching to prevent secondary bacterial skin infections.\n" +
        "• Apply cool compresses to soothe itching.\n" +
        "• Wear loose-fitting, soft cotton clothing.",
      recommendedCare: {
        clinicianType: 'Dermatologist or Primary-Care Physician',
        urgency: 'routine',
        urgencyLabel: 'Dermatological Assessment Recommended',
        reason: 'Visual inspection by a clinician is necessary to accurately distinguish contact allergy, eczema, fungal, or viral dermatoses.',
      },
      warningSigns: [
        'Rapidly spreading rash accompanied by facial swelling or wheezing (anaphylaxis alert).',
        'Blisters, skin peeling, or pus-filled lesions.',
        'Rash accompanied by high fever or purple/bruise-like spots.',
      ],
      followUpQuestions: [
        'Did the rash appear after starting a new medication, soap, or food?',
        'Is the rash itchy, painful, or warm to the touch?',
      ],
      isEmergency: false,
    };
  }

  // 14. SYMPTOM: SORE THROAT / EAR PAIN
  if (norm.includes('throat') || norm.includes('ear pain') || norm.includes('sinus') || norm.includes('swallowing')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You mentioned throat or ear discomfort.\n\n" +
        "**Possible Considerations:**\n" +
        "• Most sore throats are viral pharyngitis associated with colds.\n" +
        "• Bacterial causes (like strep throat) or ear infections (otitis media) can also cause localized pain.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Gargle with warm salt water 3–4 times daily.\n" +
        "• Drink warm herbal teas with honey or clear broths.\n" +
        "• Use throat lozenges and run a room humidifier.",
      recommendedCare: {
        clinicianType: 'ENT Specialist or Primary-Care Physician',
        urgency: 'routine',
        urgencyLabel: 'Clinical ENT Examination',
        reason: 'To inspect the pharynx, evaluate tonsillar exudates, and examine the tympanic membrane for middle-ear effusion.',
      },
      warningSigns: [
        'Inability to swallow liquids or saliva (drooling).',
        'Difficulty opening your mouth or breathing loudly.',
        'High fever with white patches on tonsils.',
      ],
      followUpQuestions: [
        'How many days have you had the sore throat or ear pain?',
        'Do you have an accompanying fever?',
      ],
      isEmergency: false,
    };
  }

  // 15. SYMPTOM: JOINT / KNEE / BACK PAIN
  if (norm.includes('knee') || norm.includes('joint') || norm.includes('back pain') || norm.includes('muscle pain')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You reported joint, knee, or muscle pain.\n\n" +
        "**Possible Considerations:**\n" +
        "• Common causes include muscular strain, ligament sprain, overuse, or mild inflammatory arthritis.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Rest the affected area and avoid strenuous loading or sudden twisting.\n" +
        "• Apply cold packs for 15–20 minutes at a time during the first 48 hours to reduce swelling.\n" +
        "• Keep the joint elevated when resting.",
      recommendedCare: {
        clinicianType: 'Orthopedic Specialist or Physical Therapist',
        urgency: 'routine',
        urgencyLabel: 'Musculoskeletal Examination',
        reason: 'To perform clinical joint stability testing, assess range of motion, and evaluate if imaging (X-ray/MRI) is warranted.',
      },
      warningSigns: [
        'Complete inability to bear weight on the leg or joint.',
        'Joint is visibly deformed, hot, red, and swollen with fever.',
        'Back pain accompanied by numbness in the groin or loss of bowel/bladder control.',
      ],
      followUpQuestions: [
        'Did the pain start after an injury or develop gradually?',
        'Is there visible swelling or stiffness in the morning?',
      ],
      isEmergency: false,
    };
  }

  // 16. SYMPTOM: STOMACH PAIN
  if (norm.includes('stomach') || norm.includes('abdomen') || norm.includes('belly') || norm.includes('cramp')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You mentioned having stomach or abdominal discomfort.\n\n" +
        "**Possible Considerations:**\n" +
        "• Common causes include indigestion, gas, dietary changes, acid reflux, or mild gastroenteritis.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Sip warm water or chamomile tea.\n" +
        "• Eat small, bland meals (toast, rice, bananas) and avoid greasy, spicy, or dairy items.\n" +
        "• Rest comfortably with knees drawn up to relieve abdominal wall tension.",
      recommendedCare: {
        clinicianType: 'Gastroenterologist or General Physician',
        urgency: 'routine',
        urgencyLabel: 'Abdominal Clinical Review',
        reason: 'To palpate abdominal quadrants, rule out appendicitis or gastritis, and assess dietary triggers.',
      },
      warningSigns: [
        'Severe, sudden pain, especially localized to the lower right abdomen.',
        'Rigid, rock-hard abdomen or pain upon touching.',
        'Vomiting blood or black tarry stools.',
      ],
      followUpQuestions: [
        'Where exactly is the pain located (upper, lower, right side)?',
        'Are you experiencing nausea, vomiting, or changes in bowel habits?',
      ],
      isEmergency: false,
    };
  }

  // 17. SYMPTOM: DIZZINESS
  if (norm.includes('dizzy') || norm.includes('dizziness') || norm.includes('lightheaded') || norm.includes('vertigo')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You reported feeling dizzy or lightheaded.\n\n" +
        "**Possible Considerations:**\n" +
        "• Dehydration, low blood sugar, standing up too quickly (orthostatic hypotension), or inner ear conditions (vertigo/BPPV) are common reasons.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Sit or lie down immediately in a safe position to prevent falls.\n" +
        "• Sip water or fruit juice if you suspect low blood sugar.\n" +
        "• Avoid sudden head turns or rapid posture changes.",
      recommendedCare: {
        clinicianType: 'General Physician / Primary-Care Doctor',
        urgency: 'prompt',
        urgencyLabel: 'Clinical Assessment Advised',
        reason: 'To evaluate blood pressure, postural vitals, blood glucose, and inner ear balance mechanisms.',
      },
      warningSigns: [
        'Dizziness accompanied by chest pain, palpitations, or shortness of breath.',
        'Sudden facial weakness, slurred speech, or arm numbness (stroke signs).',
        'Loss of consciousness or head injury from a fall.',
      ],
      followUpQuestions: [
        'Does the room feel like it is spinning (vertigo), or do you feel faint?',
        'Did this happen upon standing up quickly or while resting?',
      ],
      isEmergency: false,
    };
  }

  // 18. SYMPTOM: TIRED / FATIGUE
  if (norm.includes('tired') || norm.includes('fatigue') || norm.includes('exhausted') || norm.includes('weakness')) {
    return {
      intent: 'symptom',
      reply:
        "**Understanding Your Concern:** You mentioned feeling tired or fatigued.\n\n" +
        "**Possible Considerations:**\n" +
        "• Inadequate sleep, stress, nutritional deficiencies (iron, vitamin D/B12), dehydration, or thyroid imbalances can cause persistent tiredness.\n\n" +
        "**Useful Self-Care Steps:**\n" +
        "• Prioritize consistent 7–9 hours of sleep with regular wake-up times.\n" +
        "• Drink adequate water throughout the day.\n" +
        "• Eat balanced, nutrient-rich meals with lean protein and leafy greens.",
      recommendedCare: {
        clinicianType: 'Primary-Care Physician / General Doctor',
        urgency: 'routine',
        urgencyLabel: 'Routine Wellness & Bloodwork Review',
        reason: 'To check complete blood count (CBC for anemia), thyroid function (TSH), and essential vitamin levels.',
      },
      warningSigns: ['Sudden extreme weakness on one side of the body or chest tightness.'],
      followUpQuestions: [
        'How long have you felt unusually tired?',
        'Are you able to get 7-8 hours of restful sleep at night?',
      ],
      isEmergency: false,
    };
  }

  // 19. DEFAULT GENERAL HEALTH GUIDANCE
  return {
    intent: 'general',
    reply:
      `Regarding your inquiry on "${query}":\n\n` +
      "**MedGuard Health Information:**\n" +
      "• If you are experiencing symptoms, monitor their onset, severity, and any aggravating or relieving factors.\n" +
      "• Log your vital signs (temperature, blood pressure, blood glucose) in the **MEDGUARD Health Vault** to share with your clinician.\n" +
      "• If your symptoms are persistent or concerning, schedule an appointment with a licensed healthcare professional.\n" +
      "• For sudden, severe, or life-threatening symptoms, immediately call emergency services (108 / 112) or trigger MEDGUARD SOS.",
    recommendedCare: {
      clinicianType: 'General Physician / Primary-Care Doctor',
      urgency: 'routine',
      urgencyLabel: 'Routine Medical Consultation',
      reason: 'For personalized clinical evaluation, accurate diagnosis, and individualized health guidance.',
    },
    warningSigns: [
      'Sudden severe chest pain or shortness of breath.',
      'Loss of consciousness, severe bleeding, or neurological deficits.',
    ],
    followUpQuestions: [
      'Can you describe your symptoms or concern in more detail?',
      'How long have you noticed this?',
    ],
    isEmergency: false,
  };
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
    const norm = normalizeQuery(message);

    // 1. Triage critical life-threatening conditions immediately
    if (isEmergencyQuery(norm)) {
      return res.status(200).json({
        success: true,
        intent: 'emergency',
        reply:
          'CRITICAL EMERGENCY ALERT: Your inquiry reports severe or life-threatening symptoms. ' +
          'Please call emergency medical services immediately (108 in India, or 112 / 911) or activate the MEDGUARD SOS button in the app. ' +
          'Do not wait for online text advice or attempt to drive yourself to the hospital.',
        isEmergency: true,
        recommendedCare: {
          clinicianType: 'Emergency Department / EMS (108 / 112)',
          urgency: 'emergency',
          urgencyLabel: 'Immediate Emergency Care',
          reason: 'Reported symptoms indicate a potential acute life-threatening medical emergency.',
        },
        warningSigns: [
          'Severe crushing chest pressure or pain radiating to arm or jaw.',
          'Severe respiratory distress or inability to breathe.',
          'Sudden facial drooping, arm weakness, or slurred speech.',
        ],
        followUpQuestions: [],
        source: 'clinical_emergency_triage',
        timestamp: new Date().toISOString(),
      });
    }

    // 2. Immediate Greeting check (avoids treating "hi" as clinical emergency or self-care)
    if (isGreetingQuery(norm)) {
      return res.status(200).json({
        success: true,
        intent: 'greeting',
        reply:
          "Hello! I am MEDGUARD AI, your intelligent health companion.\n\n" +
          "I can help you understand medical topics, medication safety, symptom guidance, and MEDGUARD features. What would you like to know today?",
        recommendedCare: null,
        warningSigns: [],
        followUpQuestions: [
          'What is BMI?',
          'What is paracetamol used for?',
          'How do medicine reminders work?',
          'I have a headache',
        ],
        isEmergency: false,
        source: 'clinical_intent_engine',
        timestamp: new Date().toISOString(),
      });
    }

    // 3. Attempt Google Gemini using server-side secret
    let geminiResult = await callGeminiApi(message, history);
    if (geminiResult) {
      return res.status(200).json({
        success: true,
        ...geminiResult,
        source: 'gemini_cloud',
        timestamp: new Date().toISOString(),
      });
    }

    // 4. Clinical informational fallback if Gemini key is absent or cloud call failed
    const fallbackData = getClinicalTopicGuidance(message);
    return res.status(200).json({
      success: true,
      ...fallbackData,
      source: 'clinical_fallback_engine',
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

    if (
      Array.isArray(symptoms) &&
      symptoms.some((s) => ['chest pain', 'shortness of breath', 'dizziness'].includes(s.toLowerCase()))
    ) {
      riskLevel = 'High';
      riskScore += 40;
      recommendations.push('High-risk symptoms reported. Seek immediate clinical evaluation.');
    }

    if (recommendations.length === 0) {
      recommendations.push(
        'Vitals appear within normal ranges. Maintain regular physical activity and wellness routines.'
      );
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
