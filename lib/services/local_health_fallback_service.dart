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

    // 11. GENERAL HEALTH / DEFAULT FALLBACK
    return _buildResponse(
      query: userQuery,
      category: 'General Health',
      urgency: HealthUrgency.green,
      isEmergency: false,
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
      disclaimer:
          'MedGuard Offline Guidance: This information is general health education and does not replace professional clinical evaluation or medical diagnosis.',
    );
  }
}
