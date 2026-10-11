# MEDGUARD — MongoDB Database Schemas & Persistence Architecture

## Database Configuration
- **Database Engine:** MongoDB Atlas
- **Database Name:** `medguard`
- **Object Data Modeling (ODM):** Mongoose 9.x
- **Connection Logic:** High-reliability failover supporting replica set pooling, TLS validation, and automated index creation.

---

## 1. User & Medical Profile (`users`)
Stores user identity, authentication hashes, and baseline physical health indicators.
```javascript
{
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true, minlength: 6 },
  fullName: { type: String, required: true, trim: true },
  phoneNumber: { type: String, default: '' },
  dateOfBirth: { type: Date, default: null },
  age: { type: Number, default: null },
  gender: { type: String, enum: ['Male', 'Female', 'Other', 'Prefer not to say', ''], default: '' },
  bloodGroup: { type: String, enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', ''], default: '' },
  heightCm: { type: Number, default: null },
  weightKg: { type: Number, default: null },
  allergies: [{ type: String }],
  chronicConditions: [{ type: String }],
  emergencyMedicalInfo: { type: String, default: '' },
  emergencyContactName: { type: String, default: '' },
  emergencyCountryCode: { type: String, default: '+91' },
  emergencyPhone: { type: String, default: '' },
  emergencyRelationship: { type: String, default: '' },
  profilePictureUrl: { type: String, default: '' },
  profileCompleted: { type: Boolean, default: false },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  isActive: { type: Boolean, default: true },
  lastLoginAt: { type: Date, default: null },
  timestamps: true
}
```

---

## 2. Medicine & Reminder Logs (`medicines`)
Tracks pharmacological regimens, stock counts, and daily scheduling.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true },
  dosage: { type: String, required: true },
  frequency: { type: String, default: 'Daily' },
  times: [{ type: String }], // Array of 24h formatted strings e.g. ["08:00", "20:00"]
  startDate: { type: Date, default: Date.now },
  endDate: { type: Date },
  stockCount: { type: Number, default: 0 },
  lowStockThreshold: { type: Number, default: 5 },
  instructions: { type: String, default: '' },
  status: { type: String, enum: ['active', 'completed', 'discontinued'], default: 'active' },
  timestamps: true
}
```

---

## 3. Health Vault Documents (`healthrecords`)
Persists medical documents, lab results, prescriptions, and radiology reports.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  title: { type: String, required: true, trim: true },
  recordType: { 
    type: String, 
    enum: ['prescription', 'labReport', 'imaging', 'vaccination', 'consultation', 'other'], 
    required: true 
  },
  doctorName: { type: String, default: '' },
  hospitalName: { type: String, default: '' },
  documentDate: { type: Date, default: Date.now },
  description: { type: String, default: '' },
  fileUrl: { type: String, default: '' },
  extractedData: { type: mongoose.Schema.Types.Mixed, default: {} },
  timestamps: true
}
```

---

## 4. Clinical Appointments (`appointments`)
Manages doctor visits, clinic locations, and reminders.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  doctorName: { type: String, required: true },
  specialization: { type: String, default: '' },
  hospitalOrClinic: { type: String, default: '' },
  appointmentDate: { type: Date, required: true },
  phoneNumber: { type: String, default: '' },
  address: { type: String, default: '' },
  notes: { type: String, default: '' },
  reminderEnabled: { type: Boolean, default: true },
  reminderTimeMinutesBefore: { type: Number, default: 60 },
  selectedRemindersMinutes: [{ type: Number }], // e.g. [1440, 60, 30]
  status: { type: String, enum: ['Upcoming', 'Completed', 'Cancelled'], default: 'Upcoming' },
  pdfPath: { type: String },
  timestamps: true
}
```

---

## 5. Wellness & Hydration Tracker (`waterintakes`)
Stores daily hydration goals, fluid consumption logs, and clinician restrictions.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  amountMl: { type: Number, required: true },
  timestamp: { type: Date, default: Date.now },
  dailyTargetMl: { type: Number, default: 2500 },
  activityLevel: { type: String, enum: ['sedentary', 'moderate', 'active'], default: 'moderate' },
  clinicianFluidLimitMl: { type: Number, default: null }, // Strict clinical restriction
  timestamps: true
}
```

---

## 6. Emergency Contacts (`emergencycontacts`)
Stores authorized next-of-kin contacts for automated SMS and telephony handoff.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true },
  relation: { type: String, required: true },
  phone: { type: String, required: true },
  isPrimary: { type: Boolean, default: false },
  timestamps: true
}
```

---

## 7. Emergency Events Audit Log (`emergencyevents`)
Provides verifiable logging of all SOS triggers with verified coordinates.
```javascript
{
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  triggerType: { type: String, enum: ['voice', 'manual', 'shake'], required: true },
  location: {
    latitude: { type: Number, default: 0 },
    longitude: { type: Number, default: 0 },
    address: { type: String, default: '' }
  },
  contactsNotified: [{
    contactId: { type: mongoose.Schema.Types.ObjectId, ref: 'EmergencyContact' },
    name: { type: String },
    phone: { type: String },
    status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'sent' }
  }],
  status: { type: String, enum: ['active', 'resolved', 'cancelled'], default: 'active' },
  triggeredAt: { type: Date, default: Date.now },
  resolvedAt: { type: Date, default: null },
  timestamps: true
}
```
