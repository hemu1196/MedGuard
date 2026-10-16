# MEDGUARD — AI Diet & Fitness Page Redesign Documentation

## 1. Executive Summary & Design Rationale
The previous AI Diet & Fitness page consisted of an empty white screen with a single "Generate Meal Plan" button that triggered a placeholder snackbar. It lacked immediate clinical utility, real profile awareness, and balanced nutrition advice.

The redesigned `DietFitnessPage` (`lib/screens/addons/diet_fitness_page.dart`) replaces this with an attractive, immediately visible 7-section wellness guide adhering strictly to healthcare design standards and Material 3 principles.

---

## 2. The 7 Healthcare Wellness Sections

### Section 1: Wellness Overview (Profile-Connected Metrics)
- Automatically queries the authenticated user's profile (`ProfileRepository`).
- Displays live metrics:
  - **BMI Status**: Calculates exact BMI via `BmiCalculator.calculateBMI` (e.g. 22.9 - Normal range).
  - **Height & Weight**: Live display from user profile (e.g. 175 cm | 70 kg).
  - **Estimated Daily Calorie Target**: Based on basal metabolic rate estimation (e.g. ~2000 kcal).
  - **Recommended Daily Hydration**: Target range (2.2L - 2.5L / day).
  - **Allergy Alert Banner**: If the user has documented allergies (e.g., peanuts, lactose, shellfish), an amber alert card is prominently rendered at the top, stating that the allergen is strictly excluded from all recommendations.

### Section 2: Today's Balanced Meals
- Immediately populated without requiring network or AI latency.
- Features interactive filter chips: `All`, `Vegetarian`, `High-Protein`, `Low-Carb`.
- 5 Structured Daily Meals:
  1. 🌅 **Breakfast (7:30 - 8:30 AM)**: Oats with almonds & chia seeds / Steamed Idli with vegetable sambar / Egg white spinach omelet (~380 kcal).
  2. ☀️ **Mid-Morning Refresh (10:30 AM)**: Tender coconut water & walnuts (~120 kcal).
  3. 🥗 **Lunch (1:00 - 2:00 PM)**: Brown rice, yellow dal tadka, sauteed greens, or grilled protein bowl (~580 kcal).
  4. 🍵 **Evening Energy (4:30 - 5:00 PM)**: Sprouted moong salad or roasted makhana (~150 kcal).
  5. 🌙 **Dinner (7:30 - 8:30 PM)**: Clear vegetable soup with multi-millet roti or baked tofu/fish (~420 kcal).
- Each meal displays estimated calories, macronutrient breakdown (Carbs / Protein / Fats), and preparation guidance.

### Section 3: Daily Nutrition Principles (The Healthy Plate Method)
- Visual 3-part graphic showing optimal plate proportions:
  - 🥦 **50% Vegetables & Fruits**: Dietary fiber, micronutrients, gut microbiome support.
  - 🥩 **25% Lean Protein**: Muscle repair, tissue preservation, satiety.
  - 🌾 **25% Complex Carbohydrates**: Whole grains and millets for sustained cellular energy.

### Section 4: Healthy Movement & Activity Suggestions
- Categorized exercises with duration and intensity indicators:
  - **Morning Mobility & Stretching** (15-20 min, light)
  - **Brisk Walking / Cardio** (30-40 min, moderate, ~5,000 to 8,000 steps)
  - **Functional Bodyweight Strength** (15 min, moderate-high: squats, pushups, core holds)
  - **Post-Meal Digestive Stroll** (10 min, gentle: regulates postprandial glucose)

### Section 5: Daily Wellness Habits Checklist
- Interactive checkable cards allowing users to track their daily wellness milestones:
  - [x] Hydration (8+ glasses / 2.2L - 2.5L)
  - [x] 2+ servings of fresh greens & vegetables
  - [x] 30 minutes intentional physical movement
  - [x] 7-8 hours restful restorative sleep
  - [x] 5 minutes mindful breathing or relaxation

### Section 6: General Health Goals Focus Selector
- Selectable goal chips:
  - ⚖️ Weight Management
  - ⚡ Boost Energy
  - ❤️ Heart Health
  - 🥑 Better Digestion
  - 🩸 Blood Sugar Balance
  - 💪 Muscle Tone
- Dynamically presents targeted clinical guidance tailored to the selected goal.

### Section 7: Medical Guidance & Safety Disclaimer
- Prominently styled medical card with Shield icon:
  - *"The diet, nutrition, and exercise recommendations in MEDGUARD are provided strictly for general wellness education. They do not constitute formal medical diagnoses or prescriptions. Individuals with diabetes, hypertension, cardiovascular conditions, kidney disorders, eating disorders, or those who are pregnant or nursing should consult their primary physician or a licensed clinical nutritionist before making substantial dietary or exercise changes."*

---

## 3. On-Demand AI Tailored Plan (Optional Enhancement)
- Includes a "Personalize with AI" button powered by `GeminiService`.
- Synthesizes a custom meal and workout plan using the user's BMI, allergies, health goal, and diet style.
- Runs on-demand; failure or unavailability of the AI API never blocks or degrades the 7 default sections.

---

## 4. Navigation Integration
- In `lib/screens/profile/profile_page.dart`: The "Eat Healthy" card in the 2x2 Wellness Grid routes directly to `AppRoutes.dietFitness`.

---

## 5. Verification Verdict
**STATUS: PASS**
The AI Diet & Fitness page provides a rich, responsive, and safe healthcare lifestyle experience with immediate visibility and zero empty screens.
