const mongoose = require('mongoose');
const User = require('../models/User');
const UserSession = require('../models/UserSession');
const AuditEvent = require('../models/AuditEvent');
const EmergencyContact = require('../models/EmergencyContact');
const storageService = require('../services/storageService');
const { generateToken } = require('../utils/jwt');

/**
 * Register new user
 */
const register = async (req, res) => {
  try {
    const { email, password, fullName, name, phoneNumber } = req.body;
    const resolvedName = (fullName || name || '').trim();

    if (!email || !password || !resolvedName) {
      return res.status(400).json({
        success: false,
        message: 'Email, password, and full name are required.',
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    if (!normalizedEmail.includes('@') || !normalizedEmail.includes('.')) {
      return res.status(400).json({
        success: false,
        message: 'Please provide a valid email address.',
      });
    }

    if (String(password).length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long.',
      });
    }

    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'A user with this email already exists.',
      });
    }

    const newUser = new User({
      email: normalizedEmail,
      password: String(password),
      fullName: resolvedName,
      phoneNumber: phoneNumber ? String(phoneNumber).trim() : '',
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

    const normalizedEmail = String(email).trim().toLowerCase();
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.',
      });
    }

    const isMatch = await user.comparePassword(String(password));
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

    // Update lastLoginAt without triggering pre-save hooks
    await User.updateOne({ _id: user._id }, { $set: { lastLoginAt: new Date() } });

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
    if (resolvedPhoto !== undefined) {
      if (!resolvedPhoto) {
        if (currentUser.avatarGridFSId) {
          await storageService.deleteAvatarFromGridFS(currentUser.avatarGridFSId);
          currentUser.avatarGridFSId = null;
        }
        currentUser.profilePictureUrl = '';
      } else {
        currentUser.profilePictureUrl = String(resolvedPhoto).trim();
      }
    }

    await currentUser.save();

    // Synchronize emergency contact to authoritative EmergencyContact collection
    const cleanEmergencyPhone = (currentUser.emergencyPhone || '').trim();
    if (cleanEmergencyPhone.length >= 7) {
      try {
        const existingPrimary = await EmergencyContact.findOne({ userId: req.userId, isPrimary: true }) ||
                                await EmergencyContact.findOne({ userId: req.userId });
        if (existingPrimary) {
          if (currentUser.emergencyContactName) existingPrimary.name = currentUser.emergencyContactName;
          if (currentUser.emergencyRelationship) existingPrimary.relation = currentUser.emergencyRelationship;
          existingPrimary.phone = cleanEmergencyPhone;
          existingPrimary.isPrimary = true;
          await existingPrimary.save();
        } else {
          await EmergencyContact.create({
            userId: req.userId,
            name: currentUser.emergencyContactName || 'Emergency Contact',
            relation: currentUser.emergencyRelationship || 'Family',
            phone: cleanEmergencyPhone,
            isPrimary: true,
          });
        }
      } catch (syncErr) {
        console.warn('[AUTH CONTROLLER] Emergency contact sync note:', syncErr.message);
      }
    }

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
 * Reset password for existing account (e.g. forgot password or legacy Firebase migration)
 * Preserves user profile, health records, appointments, and all associated data.
 */
const resetPassword = async (req, res) => {
  try {
    const { email, newPassword, password } = req.body;
    const targetPassword = newPassword || password;

    if (!email || !targetPassword) {
      return res.status(400).json({
        success: false,
        message: 'Email and new password are required.',
      });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    if (String(targetPassword).length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Password must be at least 6 characters long.',
      });
    }

    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No registered account found with this email address.',
      });
    }

    // Set new password - Mongoose pre('save') hashes via bcrypt with salt 10
    user.password = String(targetPassword);
    user.lastLoginAt = new Date();
    await user.save();

    await AuditEvent.create({
      userId: user._id,
      action: 'PASSWORD_RESET',
      ipAddress: req.ip || '',
      userAgent: req.headers['user-agent'] || '',
    });

    const token = generateToken({ userId: user._id, email: user.email, role: user.role });

    await UserSession.create({
      userId: user._id,
      token,
      ipAddress: req.ip || '',
      deviceInfo: req.headers['user-agent'] || '',
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    return res.status(200).json({
      success: true,
      message: 'Password has been reset successfully. You can now log in with your new password.',
      token,
      accessToken: token,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    console.error('Reset Password Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to reset password. ' + error.message,
    });
  }
};

/**
 * Migrate or sync legacy Firebase user into MongoDB Atlas
 */
const firebaseMigrate = async (req, res) => {
  try {
    const { firebaseUid, email, password, fullName, name, phoneNumber } = req.body;
    if (!email) {
      return res.status(400).json({ success: false, message: 'Email is required.' });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const resolvedName = (fullName || name || '').trim();
    let user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      const initialPassword = password && String(password).length >= 6
        ? String(password)
        : (Math.random().toString(36).slice(-10) + 'A1!');
      user = new User({
        email: normalizedEmail,
        password: initialPassword,
        fullName: resolvedName || normalizedEmail.split('@')[0],
        phoneNumber: phoneNumber ? String(phoneNumber).trim() : '',
        firebaseUid: firebaseUid || null,
        lastLoginAt: new Date(),
      });
      await user.save();
    } else {
      let updated = false;
      if (firebaseUid && user.firebaseUid !== firebaseUid) {
        user.firebaseUid = firebaseUid;
        updated = true;
      }
      if (password && String(password).length >= 6) {
        user.password = String(password);
        updated = true;
      }
      if (updated) {
        user.lastLoginAt = new Date();
        await user.save();
      }
    }

    const token = generateToken({ userId: user._id, email: user.email, role: user.role });

    return res.status(200).json({
      success: true,
      message: 'Account successfully synchronized to MongoDB Atlas.',
      token,
      accessToken: token,
      user: user.toJSON(),
      profileCompleted: user.profileCompleted,
    });
  } catch (error) {
    console.error('Firebase Migrate Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Account synchronization failed. ' + error.message,
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

/**
 * Upload avatar image for authenticated user
 */
const uploadAvatar = async (req, res) => {
  try {
    const currentUser = await User.findById(req.userId);
    if (!currentUser) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    let file = req.file || (req.files && (req.files.avatar?.[0] || req.files.file?.[0] || req.files.image?.[0]));

    // Check if base64 data URI was sent in JSON body
    if (!file && req.body && (req.body.profilePictureUrl || req.body.avatar || req.body.image)) {
      const dataUri = req.body.profilePictureUrl || req.body.avatar || req.body.image;
      if (typeof dataUri === 'string' && dataUri.startsWith('data:image/')) {
        const matches = dataUri.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
        if (matches && matches.length === 3) {
          const mimeType = matches[1];
          const buffer = Buffer.from(matches[2], 'base64');
          file = {
            buffer,
            mimetype: mimeType,
            originalname: `avatar_${currentUser._id}.${mimeType.split('/')[1] || 'png'}`,
            size: buffer.length,
          };
        }
      }
    }

    if (!file || !file.buffer) {
      return res.status(400).json({
        success: false,
        message: 'No image file or image data provided.',
      });
    }

    // Upload to GridFS
    const uploadResult = await storageService.uploadAvatarToGridFS({
      file,
      userId: currentUser._id,
    });

    // Clean up previous avatar from GridFS if one existed
    if (currentUser.avatarGridFSId) {
      await storageService.deleteAvatarFromGridFS(currentUser.avatarGridFSId);
    }

    currentUser.avatarGridFSId = uploadResult.fileId;
    currentUser.profilePictureUrl = `/api/users/${currentUser._id}/avatar`;
    await currentUser.save();

    return res.status(200).json({
      success: true,
      message: 'Profile photo uploaded successfully.',
      user: currentUser.toJSON(),
      profilePictureUrl: currentUser.profilePictureUrl,
    });
  } catch (error) {
    console.error('Upload Avatar Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to upload profile photo: ' + error.message,
    });
  }
};

/**
 * Remove avatar image for authenticated user
 */
const removeAvatar = async (req, res) => {
  try {
    const currentUser = await User.findById(req.userId);
    if (!currentUser) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    if (currentUser.avatarGridFSId) {
      await storageService.deleteAvatarFromGridFS(currentUser.avatarGridFSId);
      currentUser.avatarGridFSId = null;
    }
    currentUser.profilePictureUrl = '';
    await currentUser.save();

    return res.status(200).json({
      success: true,
      message: 'Profile photo removed successfully.',
      user: currentUser.toJSON(),
      profilePictureUrl: '',
    });
  } catch (error) {
    console.error('Remove Avatar Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to remove profile photo: ' + error.message,
    });
  }
};

/**
 * Public streaming endpoint to get user avatar
 */
const getAvatar = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid user ID format.',
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'User account not found.',
      });
    }

    if (user.avatarGridFSId) {
      const avatarData = await storageService.getAvatarStream(user.avatarGridFSId);
      if (avatarData && avatarData.stream) {
        res.set('Content-Type', avatarData.mimeType);
        res.set('Cache-Control', 'public, max-age=86400');
        return avatarData.stream.pipe(res);
      }
    }

    if (user.profilePictureUrl) {
      if (user.profilePictureUrl.startsWith('data:image/')) {
        const matches = user.profilePictureUrl.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
        if (matches && matches.length === 3) {
          const mimeType = matches[1];
          const buffer = Buffer.from(matches[2], 'base64');
          res.set('Content-Type', mimeType);
          res.set('Cache-Control', 'public, max-age=86400');
          return res.send(buffer);
        }
      }
      if (user.profilePictureUrl.startsWith('http://') || user.profilePictureUrl.startsWith('https://')) {
        return res.redirect(user.profilePictureUrl);
      }
    }

    return res.status(404).json({
      success: false,
      message: 'No profile avatar set for this user.',
    });
  } catch (error) {
    console.error('Get Avatar Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to stream profile avatar: ' + error.message,
    });
  }
};

module.exports = {
  register,
  login,
  resetPassword,
  getMe,
  updateProfile,
  logout,
  firebaseMigrate,
  refreshToken,
  uploadAvatar,
  removeAvatar,
  getAvatar,
};
