import '../models/ai_response.dart';
import 'ai_health_service.dart';

class LocalHealthFallbackService {
  String normalizeText(String query) {
    return query
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  AIResponse generateFallback(String userQuery) {
    final clean = normalizeText(userQuery);

    // 0. GREETINGS & CASUAL INQUIRIES
    if (clean == 'hi' ||
        clean == 'hello' ||
        clean == 'hey' ||
        clean == 'hi medguard' ||
        clean == 'hello medguard' ||
        clean == 'hey medguard' ||
        clean.startsWith('hi ') ||
        clean.startsWith('hello ') ||
        clean.startsWith('hey ') ||
        clean == 'good morning' ||
        clean == 'good afternoon' ||
        clean == 'good evening' ||
        clean == 'how are you' ||
        clean == 'greetings' ||
        clean == 'help') {
      return AIResponse(
        text:
            'Hello! I am MEDGUARD Health Assistant. I can help you understand symptoms, medication safety, first aid steps, and locate emergency medical care. How can I assist you today?',
        source: AIResponseSource.localFallback,
        isFallback: true,
        category: 'Greeting',
        isEmergency: false,
        urgency: HealthUrgency.green,
        intent: 'greeting',
        understanding: 'Greeting and initial conversation.',
        followUpQuestions: const [
          'What is a healthy BMI?',
          'I have a headache',
          'How do medicine reminders work?',
          'Find nearby hospitals',
        ],
        considerations: const [],
        whatYouCanDoNow: const [],
        warningSigns: const [],
        whenToSeekMedicalHelp: '',
        disclaimer: '',
      );
    }

    // 1. EMERGENCY SYMPTOMS DETECTION
    if (clean.contains('chest pain') ||
        clean.contains('shortness of breath') ||
        clean.contains('difficulty breathing') ||
        clean.contains('can not breathe') ||
        clean.contains('cant breathe') ||
        clean.contains('numbness') ||
        clean.contains('paralysis') ||
        clean.contains('weakness on one side') ||
        clean.contains('slurred speech') ||
        clean.contains('stroke') ||
        clean.contains('heart attack') ||
        clean.contains('unconscious') ||
        clean.contains('passed out') ||
        clean.contains('severe bleeding') ||
        clean.contains('coughing blood') ||
        clean.contains('sudden severe headache')) {
      return _buildResponse(
        query: userQuery,
        category: 'Emergency',
        urgency: HealthUrgency.red,
        isEmergency: true,
        intent: 'emergency',
        recommendedCare: RecommendedCare(
          clinicianType: 'Emergency Department / Trauma Center (Call 108 / 112)',
          urgency: 'emergency',
          urgencyLabel: 'IMMEDIATE EMERGENCY CARE REQUIRED',
          reason: 'Severe red-flag symptoms require immediate clinical resuscitation and emergency transport.',
        ),
        understanding: 'Severe emergency red-flag symptoms reported.',
        followUpQuestions: [
          'Are you in a safe location right now?',
          'Is someone with you to help assist emergency responders?',
        ],
        considerations: [
          'These symptoms may indicate a serious emergency condition requiring immediate clinical evaluation.',
          'Do not attempt to drive yourself to the hospital if experiencing severe chest pain, shortness of breath, or numbness.',
        ],
        whatYouCanDoNow: [
          'Contact emergency services (108 / 911) immediately.',
          'Sit or lie down in a comfortable position while waiting for help.',
          'Alert a family member or neighbor nearby.',
        ],
        warningSigns: [
          'Loss of consciousness or confusion.',
          'Worsening chest tightness or difficulty breathing.',
          'Facial drooping or arm weakness.',
        ],
        whenToSeekMedicalHelp:
            'Call emergency services (108 / 911) or go to the nearest emergency department immediately.',
      );
    }

    // 11. BODY MASS INDEX (BMI)
    if (clean.contains('bmi') || clean.contains('body mass index')) {
      return _buildResponse(
        query: userQuery,
        category: 'Body Mass Index (BMI)',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'education',
        understanding: 'Inquiry regarding Body Mass Index (BMI) assessment.',
        followUpQuestions: [
          'What are your current height and weight measurements?',
          'Have you calculated your BMI using the MedGuard BMI tool?',
        ],
        considerations: [
          'BMI is calculated as weight in kilograms divided by height in meters squared (kg/m²).',
          'WHO Classifications: Underweight (<18.5), Normal (18.5–24.9), Overweight (25–29.9), Obesity (≥30).',
          'BMI is a screening tool and does not differentiate muscle mass from adipose fat tissue.',
        ],
        whatYouCanDoNow: [
          'Open MEDGUARD Health Vault / BMI Tracker to compute your exact category.',
          'Focus on balanced portion control and regular aerobic exercise.',
          'Consult a physician or dietitian for personalized metabolic targets.',
        ],
        warningSigns: [
          'Rapid unintentional weight loss or severe malnutrition.',
          'Elevated BMI accompanied by high blood pressure, elevated fasting glucose, or joint pain.',
        ],
        whenToSeekMedicalHelp:
            'Discuss body weight and cardiovascular risk factors with your primary physician at your next visit.',
      );
    }

    // 12. PARACETAMOL & SPECIFIC ANALGESICS
    if (clean.contains('paracetamol') ||
        clean.contains('acetaminophen') ||
        clean.contains('crocin') ||
        clean.contains('dolo') ||
        clean.contains('tylenol')) {
      return _buildResponse(
        query: userQuery,
        category: 'Medication: Paracetamol',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'medicine',
        recommendedCare: RecommendedCare(
          clinicianType: 'Pharmacist / General Physician',
          urgency: 'routine',
          urgencyLabel: 'Pharmacology Guidance',
          reason: 'Verify correct dosage strength and total 24-hour paracetamol limits across all medications.',
        ),
        understanding: 'Clinical inquiry regarding Paracetamol (Acetaminophen) safety and use.',
        followUpQuestions: [
          'What symptom (fever, headache, body pain) are you treating?',
          'Have you taken any other medications containing acetaminophen today?',
        ],
        considerations: [
          'Paracetamol is an analgesic and antipyretic indicated for mild pain and fever relief.',
          'Adult safety threshold: Maximum 4,000 mg (4 grams) per 24 hours from all combined sources.',
          'Exceeding recommended dosage carries serious danger of acute liver damage (hepatotoxicity).',
          'Avoid consuming alcohol while taking paracetamol.',
        ],
        whatYouCanDoNow: [
          'Check packaging labels for exact tablet strength (typically 500 mg or 650 mg).',
          'Space individual doses at least 4 to 6 hours apart.',
          'Track your doses in MEDGUARD Medicines tab.',
        ],
        warningSigns: [
          'Accidental overdose or consumption exceeding 4,000 mg in 24 hours.',
          'Nausea, upper right abdominal pain, or jaundice (yellowing skin/eyes).',
        ],
        whenToSeekMedicalHelp:
            'Seek immediate poison control or emergency medical evaluation if excessive doses are suspected.',
      );
    }

    // 13. APP FEATURE: MEDICINE REMINDERS
    if (clean.contains('medicine reminder') ||
        clean.contains('pill reminder') ||
        clean.contains('how do medicine reminders work') ||
        clean.contains('reminder work')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Medicine Reminders',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Guide on MEDGUARD Medicine Reminders and dose adherence.',
        followUpQuestions: [
          'Have you set your daily medication schedule in the Medicines tab?',
          'Would you like assistance configuring dosage or frequency?',
        ],
        considerations: [
          'MEDGUARD provides exact-time audio and popup notifications for scheduled medications.',
          'Marking "Taken" deducts remaining pill stock by 1 and records an adherence log entry.',
          'You can also "Snooze" alerts or "Skip" with an adherence note.',
        ],
        whatYouCanDoNow: [
          'Tap the Medicines icon in the bottom navigation bar.',
          'Add your medication name, dosage strength, scheduled times, and total pill count.',
          'Enable notifications so alarms trigger reliably on your device.',
        ],
        warningSigns: [
          'Frequent missed doses resulting in uncontrolled blood pressure, glucose, or infections.',
        ],
        whenToSeekMedicalHelp:
            'Consult your prescribing doctor if you experience side effects or need to adjust prescribed dosages.',
      );
    }

    // 14. APP FEATURE: EMERGENCY SOS & CONTACTS
    if (clean.contains('emergency contact') ||
        clean.contains('sos') ||
        clean.contains('how does sos work') ||
        clean.contains('distress')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Emergency SOS',
        urgency: HealthUrgency.red,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Overview of MEDGUARD Emergency SOS and contact broadcasting.',
        followUpQuestions: [
          'Have you registered your emergency contacts in your profile?',
          'Are your phone location permissions enabled?',
        ],
        considerations: [
          'The MEDGUARD SOS button triggers an instant alert protocol.',
          'It transmits an emergency SMS with live GPS coordinates to your registered emergency contacts.',
          'It also provides one-touch dialing to 108 (Ambulance) and 112 (National Emergency).',
        ],
        whatYouCanDoNow: [
          'Ensure at least one trusted family member or physician is listed under Emergency Contacts.',
          'Verify that location services are granted to MEDGUARD for accurate coordinates.',
        ],
        warningSigns: [
          'Life-threatening emergencies: chest pain, choking, unconsciousness, severe bleeding.',
        ],
        whenToSeekMedicalHelp:
            'Trigger the red SOS button or dial 108/112 immediately in any life-threatening situation.',
      );
    }

    // 15. APP FEATURE: AMBULANCE ASSISTANCE
    if (clean.contains('ambulance') || clean.contains('paramedic')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Ambulance Assistance',
        urgency: HealthUrgency.orange,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Guide to MEDGUARD Ambulance dispatch and calling.',
        followUpQuestions: [
          'Are you currently experiencing a medical emergency?',
          'Do you need immediate dispatch to your current location?',
        ],
        considerations: [
          'MEDGUARD connects you directly to emergency ambulance services (108 / 112).',
          'The screen displays your verified address and exact coordinates to share with dispatchers.',
        ],
        whatYouCanDoNow: [
          'Tap "Call 108 Ambulance" in the Ambulance section.',
          'Keep your phone line open and clearly state your landmark to the emergency dispatcher.',
        ],
        warningSigns: [
          'Severe trauma, cardiac arrest, respiratory failure, or stroke symptoms.',
        ],
        whenToSeekMedicalHelp:
            'Call 108 immediately for urgent emergency medical transport.',
      );
    }

    // 16. APP FEATURE: NEARBY HOSPITALS & MAP
    if (clean.contains('hospital') ||
        clean.contains('clinic') ||
        clean.contains('map') ||
        clean.contains('nearby')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Nearby Hospitals & Map',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Locating nearby healthcare facilities on MEDGUARD Explore Map.',
        followUpQuestions: [
          'Are you looking for 24/7 emergency care or outpatient clinics?',
          'Is GPS enabled on your device?',
        ],
        considerations: [
          'MEDGUARD discovers nearby medical centers using real OpenStreetMap geolocation data.',
          'Cards show distance in kilometers, estimated drive time, emergency status, and direct call buttons.',
        ],
        whatYouCanDoNow: [
          'Navigate to the Explore Map / Nearby Hospitals tab.',
          'Filter by "24/7 Emergency" for urgent trauma centers.',
          'Tap the phone icon to call facility reception directly.',
        ],
        warningSigns: [
          'Do not drive yourself if experiencing severe pain, bleeding, or dizziness; call an ambulance.',
        ],
        whenToSeekMedicalHelp:
            'Visit the nearest emergency department for acute, worsening, or traumatic conditions.',
      );
    }

    // 17. APP FEATURE: HEALTH VAULT & PDF EXPORT
    if (clean.contains('vault') ||
        clean.contains('health record') ||
        clean.contains('document') ||
        clean.contains('pdf')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Health Vault & PDF',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Managing personal health records and PDF summaries in MEDGUARD.',
        followUpQuestions: [
          'Would you like to upload a prescription, blood test, or consultation note?',
          'Do you need to download or share your health records?',
        ],
        considerations: [
          'MEDGUARD Health Vault securely stores lab reports, prescriptions, scans, and notes in MongoDB Atlas.',
          'You can generate A4 PDF summaries, convert image attachments to PDF, and share via system share sheets.',
        ],
        whatYouCanDoNow: [
          'Tap the Health Vault icon to view or add medical records.',
          'Attach doctor notes, facility names, and dates for organized clinical history.',
          'Use "Download PDF" or "Share" on any record card to distribute to your physician.',
        ],
        warningSigns: [
          'Keep your records private and only share with authorized medical personnel.',
        ],
        whenToSeekMedicalHelp:
            'Bring your exported Health Vault PDF summary to your doctor appointments.',
      );
    }

    // 18. APP FEATURE: DOCTOR APPOINTMENTS
    if (clean.contains('appointment') ||
        clean.contains('doctor visit') ||
        clean.contains('schedule visit')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Doctor Appointments',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'app_help',
        understanding: 'Scheduling and tracking clinical appointments in MEDGUARD.',
        followUpQuestions: [
          'Do you have an upcoming doctor consultation to schedule?',
        ],
        considerations: [
          'MEDGUARD schedules appointments with doctor specialty, clinic name, date, and reminders.',
          'Reminders notify you 1 day, 1 hour, or 30 minutes before your consultation.',
          'Mark visits as "Completed" or "Cancelled" to keep your medical timeline up to date.',
        ],
        whatYouCanDoNow: [
          'Open Doctor Appointments from Quick Actions or the drawer.',
          'Tap "+" to add a new visit with reminders.',
          'Download or share your Appointment Summary PDF slip.',
        ],
        warningSigns: [
          'Never postpone emergency symptoms for a future scheduled appointment.',
        ],
        whenToSeekMedicalHelp:
            'For acute symptoms, seek immediate urgent care rather than waiting for an appointment.',
      );
    }

    // 19. APP FEATURE: WATER INTAKE & HYDRATION
    if (clean.contains('water') || clean.contains('hydration') || clean.contains('drink water')) {
      return _buildResponse(
        query: userQuery,
        category: 'MedGuard Feature: Water Tracker',
        urgency: HealthUrgency.green,
        isEmergency: false,
        understanding: 'Daily hydration guidance and MEDGUARD Water Tracker.',
        followUpQuestions: [
          'How many glasses of water have you logged today?',
        ],
        considerations: [
          'A standard baseline intake is 2,000 to 2,500 mL (approx. 8–10 glasses) daily for adults.',
          'Individual fluid needs vary with climate, physical activity, and medical conditions (e.g. renal or heart failure).',
        ],
        whatYouCanDoNow: [
          'Log each glass (250 mL) in the MEDGUARD Water Tracker on the Dashboard.',
          'Monitor your progress ring toward your daily hydration goal.',
        ],
        warningSigns: [
          'Signs of severe dehydration: extreme thirst, dark urine, confusion, or fainting.',
        ],
        whenToSeekMedicalHelp:
            'Seek clinical care if severe dehydration occurs with persistent vomiting or diarrhea.',
      );
    }

    // 20. BLOOD PRESSURE & HYPERTENSION
    if (clean.contains('bp') || clean.contains('blood pressure') || clean.contains('hypertension')) {
      return _buildResponse(
        query: userQuery,
        category: 'Cardiovascular: Blood Pressure',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        understanding: 'Blood pressure classification and clinical guidance.',
        followUpQuestions: [
          'What was your latest systolic and diastolic reading?',
          'Are you currently prescribed antihypertensive medication?',
        ],
        considerations: [
          'Standard Guidelines: Normal is <120/<80 mmHg; Stage 1 Hypertension is 130–139/80–89 mmHg; Stage 2 is ≥140/≥90 mmHg.',
          'Hypertensive Crisis occurs when readings exceed 180/120 mmHg.',
        ],
        whatYouCanDoNow: [
          'Rest seated quietly for 5 minutes before taking blood pressure readings.',
          'Log your systolic and diastolic values in MEDGUARD for your physician.',
          'Reduce sodium intake and avoid smoking or caffeine prior to measurement.',
        ],
        warningSigns: [
          'Blood pressure >180/120 mmHg with headache, chest pain, or vision changes (emergency).',
        ],
        whenToSeekMedicalHelp:
            'Consult your physician if readings are consistently above 130/80 mmHg. Seek ER care for hypertensive crisis.',
      );
    }

    // 21. BLOOD SUGAR & DIABETES
    if (clean.contains('sugar') || clean.contains('glucose') || clean.contains('diabetes') || clean.contains('hypoglycemia')) {
      return _buildResponse(
        query: userQuery,
        category: 'Metabolic: Blood Glucose & Diabetes',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        understanding: 'Blood glucose targets and diabetes guidance.',
        followUpQuestions: [
          'Is this reading fasting or 2 hours post-meal?',
          'Are you experiencing shakiness, sweating, or extreme thirst?',
        ],
        considerations: [
          'Normal fasting blood glucose is 70–99 mg/dL; prediabetes is 100–125 mg/dL; diabetes is ≥126 mg/dL.',
          'Hypoglycemia occurs below 70 mg/dL and requires urgent correction.',
        ],
        whatYouCanDoNow: [
          'If hypoglycemic (<70 mg/dL): Immediately consume 15g fast-acting sugar (fruit juice or glucose tablets) and re-check in 15 min.',
          'Maintain regular meal timings and take diabetes medications as prescribed.',
        ],
        warningSigns: [
          'Severe hypoglycemia: confusion, seizures, or loss of consciousness.',
          'Diabetic ketoacidosis: fruity breath, extreme nausea, deep rapid breathing.',
        ],
        whenToSeekMedicalHelp:
            'Seek emergency medical care for severe hypoglycemia or symptoms of ketoacidosis.',
      );
    }

    // 22. BURNS & SCALDS FIRST AID
    if (clean.contains('burn') || clean.contains('scald')) {
      return _buildResponse(
        query: userQuery,
        category: 'First Aid: Burns & Scalds',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        understanding: 'First aid treatment for minor thermal burns and scalds.',
        followUpQuestions: [
          'What caused the burn (hot liquid, flame, chemical, electrical)?',
          'Is the skin red, blistering, or charred white/black?',
        ],
        considerations: [
          'Immediate cooling reduces tissue damage and pain.',
          'Never apply ice, butter, oil, or toothpaste to burns.',
        ],
        whatYouCanDoNow: [
          'Hold the burned area under cool running tap water for 10 to 20 minutes.',
          'Cover loosely with a sterile, non-adherent dressing or clean plastic wrap.',
          'Take over-the-counter pain relief if appropriate.',
        ],
        warningSigns: [
          'Burns larger than the palm of the hand, or burns on the face, hands, or groin.',
          'Chemical, electrical, or full-thickness charred burns.',
        ],
        whenToSeekMedicalHelp:
            'Seek emergency medical attention for all chemical/electrical burns, blistering over large areas, or facial burns.',
      );
    }

    // 23. ALLERGIES & ANAPHYLAXIS
    if (clean.contains('allergy') || clean.contains('allergic') || clean.contains('hives')) {
      return _buildResponse(
        query: userQuery,
        category: 'Immune: Allergy & Anaphylaxis',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        understanding: 'Assessment of allergic symptoms.',
        followUpQuestions: [
          'What triggered the reaction (food, insect sting, medication)?',
          'Are your lips, tongue, or throat swelling, or are you wheezing?',
        ],
        considerations: [
          'Mild reactions include hives, itching, and sneezing.',
          'Anaphylaxis is a life-threatening systemic reaction requiring immediate epinephrine.',
        ],
        whatYouCanDoNow: [
          'For mild localized itching, an oral antihistamine may provide relief.',
          'Avoid known triggers and record allergies in your MEDGUARD Health Profile.',
        ],
        warningSigns: [
          'ANAPHYLAXIS RED FLAGS: Lip/throat swelling, difficulty swallowing or breathing, dizziness.',
        ],
        whenToSeekMedicalHelp:
            'If lip/throat swelling or breathing difficulty occurs, use an EpiPen immediately and call 108/112.',
      );
    }

    // 24. BACK & MUSCLE STRAIN
    if (clean.contains('back pain') || clean.contains('muscle pain') || clean.contains('strain')) {
      return _buildResponse(
        query: userQuery,
        category: 'Musculoskeletal: Back & Muscle Pain',
        urgency: HealthUrgency.green,
        isEmergency: false,
        understanding: 'Back pain and muscle strain self-care guidance.',
        followUpQuestions: [
          'Did the pain start after lifting or sudden movement?',
          'Does pain shoot down your leg past the knee?',
        ],
        considerations: [
          'Acute lumbar strain usually improves over several days with gentle movement and posture care.',
          'Prolonged strict bed rest can delay recovery.',
        ],
        whatYouCanDoNow: [
          'Apply cold compresses for the first 24–48 hours, followed by warm compresses.',
          'Engage in gentle walking and avoid heavy lifting.',
        ],
        warningSigns: [
          'Loss of bladder or bowel control (cauda equina emergency).',
          'Numbness in the groin area or progressive weakness in legs/feet.',
        ],
        whenToSeekMedicalHelp:
            'Seek immediate emergency care for loss of bowel/bladder control or progressive leg weakness.',
      );
    }


    // 2. MEDICATION QUESTIONS (Prioritized for safe non-prescriptive disclaimers)
    if (clean.contains('medicine') ||
        clean.contains('pill') ||
        clean.contains('drug') ||
        clean.contains('tablet') ||
        clean.contains('dosage') ||
        clean.contains('prescribe') ||
        clean.contains('antibiotic')) {
      return _buildResponse(
        query: userQuery,
        category: 'Medication Safety',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        understanding: 'Medication inquiry or general safety question.',
        followUpQuestions: [
          'What specific symptom are you looking to address?',
          'Do you have any known drug allergies or existing health conditions?',
        ],
        considerations: [
          'I can provide general information, but medication choice and dosage should follow your doctor\'s or pharmacist\'s advice.',
          'Safe medication use depends on individual age, health history, kidney/liver function, and existing prescription interactions.',
        ],
        whatYouCanDoNow: [
          'Check the package label for active ingredients, indications, and dosage guidelines.',
          'Consult a registered pharmacist or your prescribing doctor before starting new medications.',
          'Never exceed recommended daily dosage limits.',
        ],
        warningSigns: [
          'Allergic reactions such as hives, swelling of lips/face, or difficulty breathing.',
          'Accidental overdose or severe unexpected side effects.',
        ],
        whenToSeekMedicalHelp:
            'Speak with a pharmacist or physician for personalized prescription and dosage guidance.',
      );
    }

    // 3. HEADACHE + VOMITING (Combined Cautious Category)
    if ((clean.contains('headache') || clean.contains('head hurt')) &&
        (clean.contains('vomit') || clean.contains('throw up') || clean.contains('nausea'))) {
      return _buildResponse(
        query: userQuery,
        category: 'Headache + Vomiting',
        urgency: HealthUrgency.orange,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'Urgent Care / General Physician',
          urgency: 'urgent',
          urgencyLabel: 'Urgent Medical Review',
          reason: 'Combined headache and vomiting can indicate intracranial pressure, severe migraine, or infectious etiology.',
        ),
        understanding: 'Combined symptoms of headache and vomiting.',
        followUpQuestions: [
          'Did the headache begin suddenly or gradually?',
          'Are you able to keep fluids down without vomiting?',
          'Do you have a fever, neck stiffness, or sensitivity to light?',
        ],
        considerations: [
          'Headache accompanied by vomiting requires careful monitoring as it can be caused by migraines, severe dehydration, elevated pressure, or infections.',
          'Dehydration can worsen both headache and nausea.',
        ],
        whatYouCanDoNow: [
          'Rest in a dark, quiet room with minimal screen exposure.',
          'Sip small amounts of water or oral rehydration fluids slowly.',
          'Avoid solid, oily, or spicy foods until nausea subsides.',
        ],
        warningSigns: [
          'Sudden "thunderclap" severe headache.',
          'Stiff neck, high fever, or confusion.',
          'Inability to retain liquids for more than 12 hours.',
        ],
        whenToSeekMedicalHelp:
            'Seek urgent medical evaluation at a hospital or clinic if symptoms are severe, persistent, or accompanied by neck stiffness or high fever.',
      );
    }

    // 4. HEADACHE
    if (clean.contains('headache') ||
        clean.contains('head hurt') ||
        clean.contains('head pain') ||
        clean.contains('pain in my head') ||
        clean.contains('pain in head')) {
      return _buildResponse(
        query: userQuery,
        category: 'Headache',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / Neurologist',
          urgency: 'routine',
          urgencyLabel: 'Routine Medical Evaluation',
          reason: 'Recurrent or persistent headache should be evaluated to identify triggers and appropriate preventive management.',
        ),
        understanding: 'Head pain or discomfort.',
        followUpQuestions: [
          'How long have you had this headache?',
          'Is the pain throbbing, dull, or concentrated on one side?',
          'Have you had sufficient water and rest today?',
        ],
        considerations: [
          'Headaches can have many causes including stress, muscle tension, dehydration, lack of sleep, or screen strain.',
          'Over-the-counter pain relievers can assist mild tension headaches, but should follow product labels.',
        ],
        whatYouCanDoNow: [
          'Rest in a quiet, dimmed room.',
          'Drink 1-2 glasses of water to ensure adequate hydration.',
          'Apply a cool or warm compress to your forehead or back of neck.',
          'Take a break from smartphones, computers, and TV screens.',
        ],
        warningSigns: [
          'Sudden severe headache ("worst headache of your life").',
          'Headache following a head injury.',
          'Accompanied by high fever, stiff neck, confusion, or weakness.',
        ],
        whenToSeekMedicalHelp:
            'Consult a doctor if headaches occur frequently, fail to respond to rest and hydration, or worsen progressively.',
      );
    }

    // 5. FEVER
    if (clean.contains('fever') ||
        clean.contains('temperature') ||
        clean.contains('chills') ||
        clean.contains('feeling hot')) {
      return _buildResponse(
        query: userQuery,
        category: 'Fever',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / Internal Medicine',
          urgency: 'prompt',
          urgencyLabel: 'Prompt Medical Consultation',
          reason: 'Fever persisting over 48 hours or accompanied by severe fatigue requires clinical workup to rule out bacterial or viral infection.',
        ),
        understanding: 'Elevated body temperature or feverish symptoms.',
        followUpQuestions: [
          'What is your recorded body temperature reading?',
          'How many days have you experienced this fever?',
          'Do you have a cough, sore throat, or body aches?',
        ],
        considerations: [
          'Fever is the immune system\'s natural response to fighting viral or bacterial infections.',
          'Staying well-hydrated is essential when running a fever.',
        ],
        whatYouCanDoNow: [
          'Get plenty of rest to support your immune system.',
          'Drink warm fluids, water, broth, or electrolyte drinks regularly.',
          'Wear lightweight clothing and keep room temperatures comfortable.',
          'Monitor your body temperature with a thermometer every 4-6 hours.',
        ],
        warningSigns: [
          'Fever exceeding 103°F (39.4°C) or lasting longer than 3 days.',
          'Difficulty breathing, chest discomfort, or severe lethargy.',
          'Severe headache, stiff neck, or rash.',
        ],
        whenToSeekMedicalHelp:
            'Consult a healthcare professional if fever persists beyond 48-72 hours, is very high, or is accompanied by severe discomfort.',
      );
    }

    // 6. DIZZINESS
    if (clean.contains('dizzy') ||
        clean.contains('dizziness') ||
        clean.contains('spinning') ||
        clean.contains('lightheaded') ||
        clean.contains('unsteady')) {
      return _buildResponse(
        query: userQuery,
        category: 'Dizziness',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / ENT Specialist',
          urgency: 'routine',
          urgencyLabel: 'Clinical Balance Assessment',
          reason: 'Dizziness or vertigo should be evaluated for inner ear balance disorders, cardiovascular orthostasis, or metabolic causes.',
        ),
        understanding: 'Lightheadedness, dizziness, or loss of balance.',
        followUpQuestions: [
          'Does the room feel like it is spinning (vertigo), or do you feel faint?',
          'Does dizziness occur when standing up quickly?',
          'Have you had adequate water and meals today?',
        ],
        considerations: [
          'Dizziness can stem from dehydration, low blood sugar, sudden postural changes, inner ear balance issues, or fatigue.',
          'Fall prevention is the immediate safety priority.',
        ],
        whatYouCanDoNow: [
          'Sit or lie down immediately in a safe position to prevent falling.',
          'Sip water slowly and eat a small snack if you haven\'t eaten recently.',
          'Avoid sudden movements or standing up rapidly.',
          'Avoid driving, operating machinery, or climbing stairs while dizzy.',
        ],
        warningSigns: [
          'Dizziness accompanied by chest pain, shortness of breath, or palpitations.',
          'Sudden numbness, weakness in face or limbs, or difficulty speaking.',
          'Fainting (syncope) or severe persistent head pain.',
        ],
        whenToSeekMedicalHelp:
            'Seek medical evaluation if dizziness is recurrent, severe, leads to fainting, or accompanies neurological symptoms.',
      );
    }

    // 7. STOMACH PAIN
    if (clean.contains('stomach') ||
        clean.contains('abdominal') ||
        clean.contains('belly') ||
        clean.contains('cramp') ||
        clean.contains('gut')) {
      return _buildResponse(
        query: userQuery,
        category: 'Stomach Pain',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / Gastroenterologist',
          urgency: 'prompt',
          urgencyLabel: 'Abdominal Examination Recommended',
          reason: 'Abdominal pain requires physical evaluation to differentiate benign indigestion from acute gastritis or surgical abdomen.',
        ),
        understanding: 'Abdominal or stomach pain/discomfort.',
        followUpQuestions: [
          'Where in your abdomen is the pain located (upper, lower, left, right)?',
          'Is the pain sharp, burning, or cramping in waves?',
          'Are you experiencing nausea, diarrhea, or constipation?',
        ],
        considerations: [
          'Stomach discomfort can be caused by indigestion, gas, gastritis, dietary irritation, stress, or intestinal cramping.',
          'Avoiding harsh, spicy, or greasy foods helps calm stomach irritation.',
        ],
        whatYouCanDoNow: [
          'Rest in a comfortable position (lying down with knees slightly bent can ease abdominal tension).',
          'Sip warm water, chamomile tea, or clear liquids.',
          'Apply a warm heating pad to your abdomen for mild cramping.',
          'Eat bland foods like toast, rice, or bananas if hungry.',
        ],
        warningSigns: [
          'Severe, sharp, or sudden right-lower abdominal pain.',
          'High fever, persistent vomiting, or inability to keep liquids down.',
          'Blood in vomit or stool, or severe abdomen tenderness to touch.',
        ],
        whenToSeekMedicalHelp:
            'Consult a doctor if abdominal pain is severe, persistent, or accompanied by fever, vomiting, or yellowing skin/eyes.',
      );
    }

    // 8. VOMITING / NAUSEA
    if (clean.contains('vomit') ||
        clean.contains('nausea') ||
        clean.contains('throwing up') ||
        clean.contains('sick to my stomach')) {
      return _buildResponse(
        query: userQuery,
        category: 'Vomiting & Nausea',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / Urgent Care',
          urgency: 'prompt',
          urgencyLabel: 'Hydration & Clinical Review',
          reason: 'Persistent vomiting risks electrolyte imbalance and dehydration requiring antiemetics and fluid assessment.',
        ),
        understanding: 'Nausea or vomiting discomfort.',
        followUpQuestions: [
          'How many times have you vomited today?',
          'Are you able to sip and retain small amounts of fluids?',
          'Do you have a fever, stomach pain, or diarrhea?',
        ],
        considerations: [
          'Vomiting is frequently triggered by gastroenteritis ("stomach flu"), food irritation, motion, or viral infections.',
          'Preventing dehydration is the primary goal.',
        ],
        whatYouCanDoNow: [
          'Rest your stomach for 30-60 minutes after vomiting.',
          'Sip small spoonfuls of water, clear broth, or electrolyte solution every 5-10 minutes.',
          'Avoid solid, dairy, spicy, or fatty foods until nausea clears.',
        ],
        warningSigns: [
          'Inability to keep liquids down for over 24 hours.',
          'Signs of severe dehydration (extreme thirst, dark urine, confusion, dizziness).',
          'Blood or dark coffee-ground material in vomit.',
        ],
        whenToSeekMedicalHelp:
            'Seek medical care if vomiting is severe, persistent beyond 24 hours, or accompanied by high fever or severe abdominal pain.',
      );
    }

    // 9. COUGH & COLD
    if (clean.contains('cough') ||
        clean.contains('cold') ||
        clean.contains('runny nose') ||
        clean.contains('sneezing') ||
        clean.contains('congestion')) {
      return _buildResponse(
        query: userQuery,
        category: 'Cough & Cold',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / Primary-Care Doctor',
          urgency: 'routine',
          urgencyLabel: 'Primary Care Visit if Persistent',
          reason: 'Upper respiratory infections persisting beyond 10-14 days should be evaluated for secondary bacterial infection.',
        ),
        understanding: 'Upper respiratory congestion or cough symptoms.',
        followUpQuestions: [
          'Is your cough dry or producing mucus?',
          'How many days have you experienced congestion or cough?',
          'Do you have a fever or difficulty breathing?',
        ],
        considerations: [
          'Common colds and coughs are usually viral and resolve within 7-10 days with supportive self-care.',
          'Steam inhalation and warm drinks soothe respiratory airways.',
        ],
        whatYouCanDoNow: [
          'Stay well-hydrated with warm water, herbal teas, or honey-lemon water.',
          'Use warm steam inhalation or a humidifier to loosen nasal congestion.',
          'Get ample sleep and rest.',
          'Gargle with warm salt water for throat tickles.',
        ],
        warningSigns: [
          'Difficulty breathing, wheezing, or shortness of breath.',
          'Coughing up blood or thick rusty mucus.',
          'High fever or chest pain when breathing.',
        ],
        whenToSeekMedicalHelp:
            'Consult a doctor if your cough lasts longer than 2 weeks, worsens significantly, or causes breathing difficulty.',
      );
    }

    // 10. SORE THROAT
    if (clean.contains('throat') || clean.contains('swallowing pain')) {
      return _buildResponse(
        query: userQuery,
        category: 'Sore Throat',
        urgency: HealthUrgency.green,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'General Physician / ENT Specialist',
          urgency: 'routine',
          urgencyLabel: 'Primary Care Visit',
          reason: 'Severe sore throat, especially with fever or white tonsillar exudate, requires evaluation to test for streptococcal pharyngitis.',
        ),
        understanding: 'Throat irritation or discomfort when swallowing.',
        followUpQuestions: [
          'Is the sore throat accompanied by a fever or swollen glands?',
          'Are you experiencing any difficulty swallowing liquids or breathing?',
        ],
        considerations: [
          'Sore throats commonly accompany viral infections, dry air, or throat strain.',
          'Saltwater gargles provide proven symptomatic relief.',
        ],
        whatYouCanDoNow: [
          'Gargle with warm salt water (1/2 tsp salt in 1 cup warm water) 3-4 times daily.',
          'Sip warm liquids such as tea with honey or warm soup.',
          'Use throat lozenges or spray for local soothing.',
        ],
        warningSigns: [
          'Inability to swallow liquids or open mouth fully.',
          'Difficulty breathing or noisy breathing.',
          'High fever or visible white spots on tonsils.',
        ],
        whenToSeekMedicalHelp:
            'Seek medical evaluation if sore throat is severe, lasts over 5 days, or is accompanied by high fever.',
      );
    }

    // TOOTHACHE & DENTAL PAIN
    if (clean.contains('tooth') ||
        clean.contains('teeth') ||
        clean.contains('dental') ||
        clean.contains('gum pain') ||
        clean.contains('toothache')) {
      return _buildResponse(
        query: userQuery,
        category: 'Dental: Toothache',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'Dentist / Dental Surgeon',
          urgency: 'prompt',
          urgencyLabel: 'Prompt Dental Evaluation',
          reason: 'Tooth pain often stems from dental caries, pulp inflammation, cracked tooth, or dental abscess requiring in-office examination.',
        ),
        understanding: 'Toothache or dental discomfort reported.',
        followUpQuestions: const [
          'Is the tooth sensitive to hot or cold temperatures?',
          'Do you notice any facial swelling, fever, or bleeding gums?',
          'Is the pain constant throbbing or does it happen when chewing?',
        ],
        considerations: const [
          'Tooth pain rarely resolves on its own and requires examination by a dentist.',
          'Over-the-counter pain relievers can temporarily relieve discomfort but do not treat the underlying dental cause.',
          'Warm salt water rinses can help keep the area clean and reduce inflammation.',
        ],
        whatYouCanDoNow: const [
          'Rinse your mouth gently with warm salt water (1/2 teaspoon salt in 1 glass of warm water).',
          'Floss gently around the affected tooth to dislodge trapped food particles.',
          'Avoid very hot, cold, sugary, or acidic foods and drinks.',
          'Do not apply aspirin directly to the gum tissue, as this causes chemical burns.',
        ],
        warningSigns: const [
          'Visible facial or jaw swelling, or high fever (indicates potential spreading infection).',
          'Difficulty swallowing or breathing (requires emergency care).',
          'Pus drainage or a foul taste in the mouth.',
        ],
        whenToSeekMedicalHelp:
            'Schedule a prompt appointment with a dentist. Go to an emergency center immediately if facial swelling spreads to the eye or neck.',
      );
    }

    // SKIN RASH & DERMATITIS
    if (clean.contains('rash') ||
        clean.contains('itchy skin') ||
        clean.contains('skin irritation') ||
        clean.contains('eczema') ||
        clean.contains('dermatitis')) {
      return _buildResponse(
        query: userQuery,
        category: 'Dermatology: Skin Rash',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'Dermatologist / General Physician',
          urgency: 'routine',
          urgencyLabel: 'Dermatology Consultation',
          reason: 'Cutaneous eruptions and persistent rashes require visual dermatological assessment for accurate diagnosis and prescription topicals.',
        ),
        understanding: 'Skin rash, irritation, or itching reported.',
        followUpQuestions: const [
          'Where on your body is the rash located and has it spread?',
          'Are there blisters, hives, scaling, or open sores?',
          'Did you recently come into contact with new soaps, detergents, plants, or medications?',
        ],
        considerations: const [
          'Rashes can result from contact dermatitis, viral exanthems, fungal infections, or allergic reactions.',
          'Scratching compromises the epidermal barrier and increases the risk of secondary bacterial skin infection.',
        ],
        whatYouCanDoNow: const [
          'Wash the area gently with mild, fragrance-free soap and lukewarm water.',
          'Apply a cool, damp compress or soothing calamine lotion to relieve itching.',
          'Avoid hot showers, tight synthetic clothing, and scented lotions.',
          'Keep fingernails short and avoid scratching.',
        ],
        warningSigns: const [
          'Rapidly spreading rash accompanied by high fever or shortness of breath.',
          'Purple or dark red spots that do not fade when pressed (petechiae/purpura).',
          'Skin peeling, blistering over large body areas, or involvement of eyes/mouth.',
        ],
        whenToSeekMedicalHelp:
            'Consult a dermatologist or general physician if the rash persists more than 3-5 days, worsens, or causes severe itching.',
      );
    }

    // KNEE & JOINT PAIN
    if (clean.contains('knee') ||
        clean.contains('joint') ||
        clean.contains('arthritis') ||
        clean.contains('swollen joint')) {
      return _buildResponse(
        query: userQuery,
        category: 'Musculoskeletal: Joint & Knee Pain',
        urgency: HealthUrgency.yellow,
        isEmergency: false,
        intent: 'symptom',
        recommendedCare: RecommendedCare(
          clinicianType: 'Orthopedic Specialist / Physiotherapist',
          urgency: 'routine',
          urgencyLabel: 'Musculoskeletal Evaluation',
          reason: 'Joint pain or swelling requires physical examination, range-of-motion testing, and possibly imaging (X-ray/MRI).',
        ),
        understanding: 'Joint or knee discomfort reported.',
        followUpQuestions: const [
          'Did the pain begin following an acute twist, fall, or sports injury?',
          'Is there visible swelling, warmth, or redness around the joint?',
          'Are you able to bear weight and walk on the leg?',
        ],
        considerations: const [
          'Joint pain may be caused by ligament sprains, meniscus tears, tendonitis, or osteoarthritis.',
          'Protecting the joint from further strain while maintaining gentle mobility accelerates recovery.',
        ],
        whatYouCanDoNow: const [
          'Follow the R.I.C.E protocol: Rest, Ice (15-20 min intervals), gentle Compression, and Elevation.',
          'Avoid high-impact jumping, running, or deep squatting.',
          'Use supportive footwear and avoid walking barefoot on hard floors.',
        ],
        warningSigns: const [
          'Complete inability to bear weight or joint "giving way" or locking.',
          'Rapid severe swelling, redness, and heat (possible septic arthritis).',
          'Visible deformity or numbness below the joint.',
        ],
        whenToSeekMedicalHelp:
            'Schedule a consultation with an orthopedic specialist if joint pain persists for more than a week, impairs walking, or recurs frequently.',
      );
    }

    // 25. GENERAL HEALTH / DEFAULT FALLBACK
    return _buildResponse(
      query: userQuery,
      category: 'General Health',
      urgency: HealthUrgency.green,
      isEmergency: false,
      intent: 'general',
      understanding: 'General health or symptom inquiry.',
      followUpQuestions: [
        'How long have you noticed these symptoms?',
        'Are your symptoms mild, moderate, or worsening?',
        'Are there any other symptoms present?',
      ],
      considerations: [
        'Maintaining hydration, adequate sleep, balanced nutrition, and low stress supports general physical wellness.',
        'Listening to your body and tracking symptom duration provides helpful context for healthcare visits.',
      ],
      whatYouCanDoNow: [
        'Rest in a comfortable environment and maintain regular fluid intake.',
        'Keep a record of your symptoms and when they occur.',
        'Avoid strenuous exertion until feeling well.',
      ],
      warningSigns: [
        'Sudden, severe, or unexplained symptom onset.',
        'Chest discomfort, breathing distress, or fainting.',
      ],
      whenToSeekMedicalHelp:
        'Consult a qualified healthcare provider if symptoms persist, cause concern, or interfere with daily activities.',
    );
  }

  AIResponse _buildResponse({
    required String query,
    required String category,
    required HealthUrgency urgency,
    required bool isEmergency,
    required String understanding,
    required List<String> followUpQuestions,
    required List<String> considerations,
    required List<String> whatYouCanDoNow,
    required List<String> warningSigns,
    required String whenToSeekMedicalHelp,
    String intent = 'symptom',
    RecommendedCare? recommendedCare,
    String? disclaimer,
  }) {
    final bodyBuffer = StringBuffer();
    bodyBuffer.writeln('Summary: $understanding\n');
    bodyBuffer.writeln('Considerations:');
    for (final c in considerations) {
      bodyBuffer.writeln('• $c');
    }
    bodyBuffer.writeln('\nRecommended Actions:');
    for (final a in whatYouCanDoNow) {
      bodyBuffer.writeln('• $a');
    }
    bodyBuffer.writeln('\nWhen to Seek Help:\n$whenToSeekMedicalHelp');

    return AIResponse(
      text: bodyBuffer.toString(),
      source: AIResponseSource.localFallback,
      isFallback: true,
      category: category,
      isEmergency: isEmergency,
      urgency: urgency,
      understanding: understanding,
      followUpQuestions: followUpQuestions,
      considerations: considerations,
      whatYouCanDoNow: whatYouCanDoNow,
      warningSigns: warningSigns,
      whenToSeekMedicalHelp: whenToSeekMedicalHelp,
      disclaimer: disclaimer ??
          'MedGuard Offline Guidance: This information is general health education and does not replace professional clinical evaluation or medical diagnosis.',
      intent: intent,
      recommendedCare: recommendedCare,
    );
  }
}
