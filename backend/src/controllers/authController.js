const User = require('../models/User');
const UserSession = require('../models/UserSession');
const AuditEvent = require('../models/AuditEvent');
const { generateToken } = require('../utils/jwt');

/**
 * Register new user
 */
const register = async (req, res) => {
  try {
    const { email, password, fullName, name, phoneNumber } = req.body;
    const resolvedName = fullName || name;

    if (!email || !password || !resolvedName) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, and full name are required.',
      });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'A user with this email already exists.',
      });
    }

    const newUser = new User({
      email,
      password,
      fullName: resolvedName,
      phoneNumber: phoneNumber || '',
      lastLoginAt: new Date(),
    });

    await newUser.save();

    const token = generateToken({ userId: newUser._id, email: newUser.email, role: newUser.role });

    await UserSession.create({
      userId: newUser._id,
      token,
      ipAddress: req.ip || '',
      deviceInfo: req.headers['user-agent'] || '',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    await AuditEvent.create({
      userId: newUser._id,
      action: 'USER_REGISTER',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
    });

    return res.status(201).json({
      success: true,
      message: 'Registration successful.',
      token,
      accessToken: token,
      user: newUser.toJSON(),
      profileCompleted: newUser.profileCompleted,
    });
  } catch (error) {
    console.error('Register Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to register user. ' + error.message,
    });
  }
};

/**
 * Login user
 */
const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required.',
      });
    }

    const user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    const isMatch = await user.comparePassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: 'Account is disabled.',
      });
    }

    user.lastLoginAt = new Date();
    await user.save();

    const token = generateToken({ userId: user._id, email: user.email, role: user.role });

    await UserSession.create({
      userId: user._id,
      token,
      ipAddress: req.ip || '',
      deviceInfo: req.headers['user-agent'] || '',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    await AuditEvent.create({
      userId: user._id,
      action: 'USER_LOGIN',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
    });

    return res.status(200).json({
      success: true,
      message: 'Login successful.',
      token,
      accessToken: token,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    console.error('Login Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Login failed. ' + error.message,
    });
  }
};

/**
 * Get currently authenticated user profile
 */
const getMe = async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Authenticated user account no longer exists.',
      });
    }

    return res.status(200).json({
      success: true,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch user profile.',
    });
  }
};

/**
 * Update current user profile
 */
const updateProfile = async (req, res) => {
  try {
    const currentUser = await User.findById(req.userId);
    if (!currentUser) {
      return res.status(404).json({
        success: false,
        message: 'Authenticated user account not found.',
      });
    }

    const {
      fullName, name,
      phoneNumber, emergencyPhone,
      dateOfBirth, age,
      gender, bloodGroup,
      heightCm, height,
      weightKg, weight,
      allergies, chronicConditions, existingConditions,
      emergencyMedicalInfo, currentMedications,
      emergencyContactName, emergencyCountryCode, emergencyRelationship,
      profilePictureUrl, profileImagePath,
    } = req.body;

    const resolvedName = fullName || name;
    if (resolvedName !== undefined && resolvedName !== null) {
      currentUser.fullName = String(resolvedName).trim();
    }

    const resolvedPhone = phoneNumber || emergencyPhone;
    if (resolvedPhone !== undefined && resolvedPhone !== null) {
      currentUser.phoneNumber = String(resolvedPhone).trim();
    }

    if (dateOfBirth !== undefined) {
      if (dateOfBirth === null || dateOfBirth === '') {
        currentUser.dateOfBirth = null;
      } else {
        const parsedDob = new Date(dateOfBirth);
        if (!isNaN(parsedDob.getTime())) {
          currentUser.dateOfBirth = parsedDob;
        }
      }
    }

    if (age !== undefined && age !== null && age !== '') {
      const parsedAge = Number(age);
      if (!isNaN(parsedAge) && parsedAge >= 0) {
        currentUser.age = parsedAge;
      }
    }

    if (gender !== undefined && gender !== null) {
      currentUser.gender = String(gender).trim();
    }

    if (bloodGroup !== undefined && bloodGroup !== null) {
      currentUser.bloodGroup = String(bloodGroup).trim();
    }

    const resolvedHeight = heightCm !== undefined ? heightCm : height;
    if (resolvedHeight !== undefined && resolvedHeight !== null && resolvedHeight !== '') {
      const h = Number(resolvedHeight);
      if (!isNaN(h) && h > 0) {
        currentUser.heightCm = h;
      }
    }

    const resolvedWeight = weightKg !== undefined ? weightKg : weight;
    if (resolvedWeight !== undefined && resolvedWeight !== null && resolvedWeight !== '') {
      const w = Number(resolvedWeight);
      if (!isNaN(w) && w > 0) {
        currentUser.weightKg = w;
      }
    }

    if (allergies !== undefined && allergies !== null) {
      if (Array.isArray(allergies)) {
        currentUser.allergies = allergies.map(s => String(s).trim()).filter(Boolean);
      } else if (typeof allergies === 'string') {
        currentUser.allergies = allergies.split(',').map(s => s.trim()).filter(Boolean);
      }
    }

    const resolvedConditions = chronicConditions !== undefined ? chronicConditions : existingConditions;
    if (resolvedConditions !== undefined && resolvedConditions !== null) {
      if (Array.isArray(resolvedConditions)) {
        currentUser.chronicConditions = resolvedConditions.map(s => String(s).trim()).filter(Boolean);
      } else if (typeof resolvedConditions === 'string') {
        currentUser.chronicConditions = resolvedConditions.split(',').map(s => s.trim()).filter(Boolean);
      }
    }

    const resolvedMedInfo = emergencyMedicalInfo !== undefined ? emergencyMedicalInfo : currentMedications;
    if (resolvedMedInfo !== undefined && resolvedMedInfo !== null) {
      currentUser.emergencyMedicalInfo = String(resolvedMedInfo).trim();
    }

    if (emergencyContactName !== undefined && emergencyContactName !== null) {
      currentUser.emergencyContactName = String(emergencyContactName).trim();
    }

    if (emergencyCountryCode !== undefined && emergencyCountryCode !== null) {
      currentUser.emergencyCountryCode = String(emergencyCountryCode).trim();
    }

    if (emergencyPhone !== undefined && emergencyPhone !== null) {
      currentUser.emergencyPhone = String(emergencyPhone).trim();
    }

    if (emergencyRelationship !== undefined && emergencyRelationship !== null) {
      currentUser.emergencyRelationship = String(emergencyRelationship).trim();
    }

    const resolvedPhoto = profilePictureUrl !== undefined ? profilePictureUrl : profileImagePath;
    if (resolvedPhoto !== undefined && resolvedPhoto !== null) {
      currentUser.profilePictureUrl = String(resolvedPhoto);
    }

    await currentUser.save();

    await AuditEvent.create({
      userId: req.userId,
      action: 'PROFILE_UPDATE',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
      details: { updatedFields: Object.keys(req.body) },
    });

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully.',
      user: currentUser.toJSON(),
      profileCompleted: currentUser.profileCompleted,
    });
  } catch (error) {
    console.error('Update Profile Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update profile. ' + error.message,
    });
  }
};

/**
 * Logout
 */
const logout = async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      const token = authHeader.split(' ')[1];
      await UserSession.updateMany({ token }, { $set: { isActive: false } });
    }

    await AuditEvent.create({
      userId: req.userId,
      action: 'USER_LOGOUT',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
    });

    return res.status(200).json({
      success: true,
      message: 'Logged out successfully.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Logout failed.',
    });
  }
};

/**
 * Migrate or sync legacy Firebase user into MongoDB Atlas
 */
const firebaseMigrate = async (req, res) => {
  try {
    const { firebaseUid, email, fullName, name, phoneNumber } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    const resolvedName = fullName || name;
    let user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      const randomPassword = Math.random().toString(36).slice(-10) + 'A1!';
      user = new User({
        email,
        password: randomPassword,
        fullName: resolvedName || email.split('@')[0],
        phoneNumber: phoneNumber || '',
        firebaseUid: firebaseUid || null,
      });
      await user.save();
    } else if (firebaseUid && !user.firebaseUid) {
      user.firebaseUid = firebaseUid;
      await user.save();
    }

    const token = generateToken({ userId: user._id, email: user.email, role: user.role });

    return res.status(200).json({
      success: true,
      message: 'Firebase user synced to MongoDB Atlas.',
      token,
      accessToken: token,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    console.error('Firebase Migrate Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Firebase migration failed. ' + error.message,
    });
  }
};

/**
 * Refresh access token
 */
const refreshToken = async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user || !user.isActive) {
      return res.status(401).json({
        success: false,
        message: 'Invalid or inactive user account.',
      });
    }

    const token = generateToken({ userId: user._id, email: user.email, role: user.role });

    return res.status(200).json({
      success: true,
      message: 'Token refreshed successfully.',
      token,
      accessToken: token,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    console.error('Refresh Token Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to refresh token.',
    });
  }
};

module.exports = {
  register,
  login,
  getMe,
  updateProfile,
  logout,
  firebaseMigrate,
  refreshToken,
};
