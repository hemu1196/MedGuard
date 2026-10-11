const EmergencyContact = require('../models/EmergencyContact');
const EmergencyEvent = require('../models/EmergencyEvent');
const User = require('../models/User');

const getEmergencyContacts = async (req, res) => {
  try {
    let contacts = await EmergencyContact.find({ userId: req.userId }).sort({ isPrimary: -1, createdAt: -1 });

    // Safe synchronization: If EmergencyContact collection has 0 contacts, check User profile from onboarding
    if (contacts.length === 0) {
      const user = await User.findById(req.userId);
      if (user && user.emergencyPhone && user.emergencyPhone.trim().length >= 7) {
        const autoContact = new EmergencyContact({
          userId: req.userId,
          name: user.emergencyContactName || 'Emergency Contact',
          relation: user.emergencyRelationship || 'Family',
          phone: user.emergencyPhone.trim(),
          isPrimary: true,
        });
        await autoContact.save();
        contacts = [autoContact];
      }
    }

    return res.status(200).json({
      success: true,
      contacts,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch emergency contacts: ' + error.message,
    });
  }
};

const addEmergencyContact = async (req, res) => {
  try {
    const { name, relation, phone, isPrimary } = req.body;

    if (!name || !relation || !phone) {
      return res.status(400).json({
        success: false,
        message: 'Name, relation, and phone number are required.',
      });
    }

    const existingCount = await EmergencyContact.countDocuments({ userId: req.userId });
    const shouldBePrimary = isPrimary !== undefined ? !!isPrimary : existingCount === 0;

    if (shouldBePrimary) {
      await EmergencyContact.updateMany({ userId: req.userId }, { $set: { isPrimary: false } });
    }

    const contact = new EmergencyContact({
      userId: req.userId,
      name: name.trim(),
      relation: relation.trim(),
      phone: phone.trim(),
      isPrimary: shouldBePrimary,
    });

    await contact.save();

    // Synchronize to User profile if primary
    if (shouldBePrimary) {
      await User.findByIdAndUpdate(req.userId, {
        emergencyContactName: contact.name,
        emergencyRelationship: contact.relation,
        emergencyPhone: contact.phone,
      });
    }

    return res.status(201).json({
      success: true,
      message: 'Emergency contact added successfully.',
      contact,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to add emergency contact: ' + error.message,
    });
  }
};

const updateEmergencyContact = async (req, res) => {
  try {
    const { contactId } = req.params;
    const { name, relation, phone, isPrimary } = req.body;

    const contact = await EmergencyContact.findOne({ _id: contactId, userId: req.userId });
    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Emergency contact not found.',
      });
    }

    if (isPrimary) {
      await EmergencyContact.updateMany({ userId: req.userId }, { $set: { isPrimary: false } });
    }

    if (name) contact.name = name.trim();
    if (relation) contact.relation = relation.trim();
    if (phone) contact.phone = phone.trim();
    if (isPrimary !== undefined) contact.isPrimary = !!isPrimary;

    await contact.save();

    // If primary, update User profile
    if (contact.isPrimary) {
      await User.findByIdAndUpdate(req.userId, {
        emergencyContactName: contact.name,
        emergencyRelationship: contact.relation,
        emergencyPhone: contact.phone,
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Emergency contact updated successfully.',
      contact,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to update emergency contact: ' + error.message,
    });
  }
};

const setPrimaryEmergencyContact = async (req, res) => {
  try {
    const { contactId } = req.params;
    const contact = await EmergencyContact.findOne({ _id: contactId, userId: req.userId });
    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Emergency contact not found.',
      });
    }

    await EmergencyContact.updateMany({ userId: req.userId }, { $set: { isPrimary: false } });
    contact.isPrimary = true;
    await contact.save();

    await User.findByIdAndUpdate(req.userId, {
      emergencyContactName: contact.name,
      emergencyRelationship: contact.relation,
      emergencyPhone: contact.phone,
    });

    return res.status(200).json({
      success: true,
      message: 'Primary emergency contact set successfully.',
      contact,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to set primary emergency contact: ' + error.message,
    });
  }
};

const deleteEmergencyContact = async (req, res) => {
  try {
    const { contactId } = req.params;
    const contact = await EmergencyContact.findOne({ _id: contactId, userId: req.userId });
    if (!contact) {
      return res.status(404).json({
        success: false,
        message: 'Emergency contact not found.',
      });
    }

    const wasPrimary = contact.isPrimary;
    await EmergencyContact.deleteOne({ _id: contactId, userId: req.userId });

    // If deleted contact was primary, promote next remaining contact if any
    if (wasPrimary) {
      const nextContact = await EmergencyContact.findOne({ userId: req.userId }).sort({ createdAt: -1 });
      if (nextContact) {
        nextContact.isPrimary = true;
        await nextContact.save();
        await User.findByIdAndUpdate(req.userId, {
          emergencyContactName: nextContact.name,
          emergencyRelationship: nextContact.relation,
          emergencyPhone: nextContact.phone,
        });
      } else {
        await User.findByIdAndUpdate(req.userId, {
          emergencyContactName: '',
          emergencyRelationship: '',
          emergencyPhone: '',
        });
      }
    }

    return res.status(200).json({
      success: true,
      message: 'Emergency contact deleted successfully.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to delete emergency contact: ' + error.message,
    });
  }
};

const triggerSos = async (req, res) => {
  try {
    const { triggerType, latitude, longitude, address } = req.body;

    const lat = (latitude !== undefined && latitude !== null && !isNaN(Number(latitude))) ? Number(latitude) : 0;
    const lng = (longitude !== undefined && longitude !== null && !isNaN(Number(longitude))) ? Number(longitude) : 0;

    const contacts = await EmergencyContact.find({ userId: req.userId });

    const contactsNotified = contacts.map((c) => ({
      contactId: c._id,
      name: c.name,
      phone: c.phone,
      status: 'sent',
    }));

    const mapsUrl = (lat !== 0 || lng !== 0)
      ? `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`
      : 'Location unavailable';
    const senderName = (req.user && req.user.fullName) ? req.user.fullName : 'MEDGUARD User';
    const smsMessage = `EMERGENCY ALERT from ${senderName}! I need immediate medical assistance. My live location: ${mapsUrl}`;

    const sosEvent = new EmergencyEvent({
      userId: req.userId,
      triggerType: triggerType || 'manual',
      location: {
        latitude: lat,
        longitude: lng,
        address: address || (lat === 0 && lng === 0 ? 'Location unavailable' : ''),
      },
      contactsNotified,
      status: 'active',
      triggeredAt: new Date(),
    });

    await sosEvent.save();

    return res.status(200).json({
      success: true,
      message: 'SOS Emergency Event logged successfully.',
      event: sosEvent,
      mapsUrl,
      smsMessage,
      contacts: contactsNotified,
    });
  } catch (error) {
    console.error('Trigger SOS Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to process SOS trigger. ' + error.message,
    });
  }
};

const getSosHistory = async (req, res) => {
  try {
    const events = await EmergencyEvent.find({ userId: req.userId }).sort({ triggeredAt: -1 }).limit(50);
    return res.status(200).json({
      success: true,
      events,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch SOS history.',
    });
  }
};

module.exports = {
  getEmergencyContacts,
  addEmergencyContact,
  updateEmergencyContact,
  setPrimaryEmergencyContact,
  deleteEmergencyContact,
  triggerSos,
  getSosHistory,
};
