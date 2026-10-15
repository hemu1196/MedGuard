const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true,
  },
  password: {
    type: String,
    required: true,
    minlength: 6,
  },
  fullName: {
    type: String,
    required: true,
    trim: true,
  },
  phoneNumber: {
    type: String,
    default: '',
  },
  dateOfBirth: {
    type: Date,
    default: null,
  },
  age: {
    type: Number,
    default: null,
  },
  gender: {
    type: String,
    enum: ['Male', 'Female', 'Other', 'Prefer not to say', ''],
    default: '',
  },
  bloodGroup: {
    type: String,
    enum: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', ''],
    default: '',
  },
  heightCm: {
    type: Number,
    default: null,
  },
  weightKg: {
    type: Number,
    default: null,
  },
  allergies: [{
    type: String,
  }],
  chronicConditions: [{
    type: String,
  }],
  emergencyMedicalInfo: {
    type: String,
    default: '',
  },
  emergencyContactName: {
    type: String,
    default: '',
  },
  emergencyCountryCode: {
    type: String,
    default: '+91',
  },
  emergencyPhone: {
    type: String,
    default: '',
  },
  emergencyRelationship: {
    type: String,
    default: '',
  },
  profilePictureUrl: {
    type: String,
    default: '',
  },
  avatarGridFSId: {
    type: mongoose.Schema.Types.ObjectId,
    default: null,
  },
  profileCompleted: {
    type: Boolean,
    default: false,
  },
  firebaseUid: {
    type: String,
    default: null,
    sparse: true,
  },
  role: {
    type: String,
    enum: ['user', 'admin'],
    default: 'user',
  },
  isActive: {
    type: Boolean,
    default: true,
  },
  lastLoginAt: {
    type: Date,
    default: null,
  },
}, {
  timestamps: true,
});

userSchema.pre('save', async function (next) {
  if (this.isModified('password')) {
    try {
      const salt = await bcrypt.genSalt(10);
      this.password = await bcrypt.hash(this.password, salt);
    } catch (err) {
      return next(err);
    }
  }

  // Auto-calculate age if dateOfBirth is present and age is null/unmodified
  if (this.dateOfBirth) {
    const dob = new Date(this.dateOfBirth);
    const now = new Date();
    let calculatedAge = now.getFullYear() - dob.getFullYear();
    const monthDiff = now.getMonth() - dob.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dob.getDate())) {
      calculatedAge--;
    }
    if (calculatedAge >= 0) {
      this.age = calculatedAge;
    }
  }

  // Auto-evaluate profileCompleted status
  const hasName = this.fullName && this.fullName.trim().length > 0;
  const hasGender = this.gender && this.gender.trim().length > 0;
  const hasAgeOrDob = (this.age !== null && this.age >= 0) || this.dateOfBirth !== null;
  const hasHeight = this.heightCm !== null && this.heightCm > 0;
  const hasWeight = this.weightKg !== null && this.weightKg > 0;

  if (hasName && hasGender && hasAgeOrDob && hasHeight && hasWeight) {
    this.profileCompleted = true;
  }

  next();
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

userSchema.methods.toJSON = function () {
  const obj = this.toObject();
  delete obj.password;

  // Add alias fields for frontend compatibility
  obj.name = obj.fullName;
  obj.isProfileComplete = obj.profileCompleted;
  
  if (obj.dateOfBirth && (obj.age === null || obj.age === undefined)) {
    const dob = new Date(obj.dateOfBirth);
    const now = new Date();
    let calculatedAge = now.getFullYear() - dob.getFullYear();
    const monthDiff = now.getMonth() - dob.getMonth();
    if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < dob.getDate())) {
      calculatedAge--;
    }
    obj.age = calculatedAge >= 0 ? calculatedAge : 0;
  }

  return obj;
};

module.exports = mongoose.model('User', userSchema);
