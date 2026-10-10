const User = require('../models/User');
const UserSession = require('../models/UserSession');
const AuditEvent = require('../models/AuditEvent');
const { generateToken } = require('../utils/jwt');

/**
 * Register new user
 */
const register = async (req, res) => {
  try {
    const { email, password, fullName, phoneNumber } = req.body;

    if (!email || !password || !fullName) {
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
      fullName,
      phoneNumber: phoneNumber || '',
      lastLoginAt: new Date(),
    });

    await newUser.save();

    const token = generateToken({ userId: newUser._id, email: newUser.email, role: newUser.role });

    // Store user session
    await UserSession.create({
      userId: newUser._id,
      token,
      ipAddress: req.ip || '',
      deviceInfo: req.headers['user-agent'] || '',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    // Audit log
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
      user: newUser.toJSON(),
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

    // Create active session
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
      user: user.toJSON(),
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
    return res.status(200).json({
      success: true,
      user: req.user.toJSON(),
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
    const allowedUpdates = [
      'fullName', 'phoneNumber', 'age', 'gender', 'bloodGroup',
      'heightCm', 'weightKg', 'allergies', 'chronicConditions',
      'emergencyMedicalInfo', 'profilePictureUrl',
    ];

    const updates = {};
    for (const key of Object.keys(req.body)) {
      if (allowedUpdates.includes(key)) {
        updates[key] = req.body[key];
      }
    }

    const updatedUser = await User.findByIdAndUpdate(
      req.userId,
      { $set: updates },
      { new: true, runValidators: true }
    );

    await AuditEvent.create({
      userId: req.userId,
      action: 'PROFILE_UPDATE',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
      details: { updatedFields: Object.keys(updates) },
    });

    return res.status(200).json({
      success: true,
      message: 'Profile updated successfully.',
      user: updatedUser.toJSON(),
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
    const { firebaseUid, email, fullName, phoneNumber } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    let user = await User.findOne({ email: email.toLowerCase() });
    if (!user) {
      // Create user record for migrated firebase user
      const randomPassword = Math.random().toString(36).slice(-10) + 'A1!';
      user = new User({
        email,
        password: randomPassword,
        fullName: fullName || email.split('@')[0],
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
      user: user.toJSON(),
    });
  } catch (error) {
    console.error('Firebase Migrate Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Firebase migration failed. ' + error.message,
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
};
