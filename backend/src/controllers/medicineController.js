const Medicine = require('../models/Medicine');
const MedicationLog = require('../models/MedicationLog');

const getMedicines = async (req, res) => {
  try {
    const medicines = await Medicine.find({ userId: req.userId, isActive: true }).sort({ createdAt: -1 });
    return res.status(200).json({
      success: true,
      medicines,
    });
  } catch (error) {
    console.error('Get Medicines Error:', error.name);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch medicines. ' + error.message,
    });
  }
};

const addMedicine = async (req, res) => {
  try {
    const { name, dosage, times, frequency, totalStock, remainingStock, instructions, startDate, endDate } = req.body;

    if (!name || !dosage) {
      return res.status(400).json({
        success: false,
        message: 'Medicine name and dosage are required.',
      });
    }

    const newMedicine = new Medicine({
      userId: req.userId,
      name,
      dosage,
      times: times || ['08:00'],
      frequency: frequency || 'Daily',
      totalStock: totalStock !== undefined ? Number(totalStock) : 30,
      remainingStock: remainingStock !== undefined ? Number(remainingStock) : (totalStock !== undefined ? Number(totalStock) : 30),
      weekdays: req.body.weekdays || [], dosageQuantity: req.body.dosageQuantity || 1, refillThreshold: req.body.refillThreshold ?? 5,
      instructions: instructions || '',
      startDate: startDate ? new Date(startDate) : new Date(),
      endDate: endDate ? new Date(endDate) : null,
    });

    await newMedicine.save();

    return res.status(201).json({
      success: true,
      message: 'Medicine added successfully.',
      medicine: newMedicine,
    });
  } catch (error) {
    console.error('Add Medicine Error:', error.name);
    return res.status(500).json({
      success: false,
      message: 'Failed to add medicine. ' + error.message,
    });
  }
};

const updateMedicine = async (req, res) => {
  try {
    const { medicineId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(medicineId)) {
      return res.status(404).json({
        success: false,
        message: 'Invalid medicine ID format.',
      });
    }
    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });

    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    const updates = req.body;
    if (['times', 'frequency', 'startDate', 'endDate', 'weekdays', 'dosageQuantity'].some(key => Object.hasOwn(updates, key) && JSON.stringify(medicine[key]) !== JSON.stringify(updates[key]))) {
      medicine.scheduleVersion = (medicine.scheduleVersion || 1) + 1;
    }
    Object.keys(updates).forEach((key) => {
      if (['name', 'dosage', 'times', 'frequency', 'totalStock', 'remainingStock', 'instructions', 'startDate', 'endDate', 'weekdays', 'dosageQuantity', 'refillThreshold'].includes(key)) {
        medicine[key] = updates[key];
      }
    });

    await medicine.save();

    return res.status(200).json({
      success: true,
      message: 'Medicine updated successfully.',
      medicine,
    });
  } catch (error) {
    console.error('Update Medicine Error:', error.name);
    return res.status(500).json({
      success: false,
      message: 'Failed to update medicine. ' + error.message,
    });
  }
};

const mongoose = require('mongoose');

const deleteMedicine = async (req, res) => {
  try {
    const { medicineId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(medicineId)) {
      return res.status(404).json({
        success: false,
        message: 'Invalid medicine ID format.',
      });
    }

    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });

    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    await Medicine.deleteOne({ _id: medicineId, userId: req.userId });

    return res.status(200).json({
      success: true,
      message: 'Medicine removed successfully.',
    });
  } catch (error) {
    console.error('Delete Medicine Error:', error.name);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete medicine: ' + error.message,
    });
  }
};

const logMedicationAction = async (req, res) => {
  try {
    const { medicineId, scheduledTime, status, missedReason } = req.body;

    if (!medicineId || !scheduledTime || !status) {
      return res.status(400).json({
        success: false,
        message: 'medicineId, scheduledTime, and status are required.',
      });
    }

    if (!mongoose.Types.ObjectId.isValid(medicineId) || !['taken', 'skipped', 'missed'].includes(status) || typeof scheduledTime !== 'string') {
      return res.status(400).json({ success: false, message: 'Valid medicine ID, scheduled time, and medication status are required.' });
    }
    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });
    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    const result = await require('../services/doseActionService').recordDose({
      userId: req.userId, medicineId, scheduledTime, scheduledDate: req.body.scheduledDate,
      status, missedReason,
    });
    return res.status(result.status).json(result);

  } catch (error) {
    console.error('Log Medication Action Error:', error.name);
    return res.status(500).json({
      success: false,
      message: 'Failed to record medication action. ' + error.message,
    });
  }
};

const getMedicationLogs = async (req, res) => {
  try {
    const logs = await MedicationLog.find({ userId: req.userId }).sort({ createdAt: -1 }).limit(100);
    return res.status(200).json({
      success: true,
      logs,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch medication logs.',
    });
  }
};

module.exports = {
  getMedicines,
  addMedicine,
  updateMedicine,
  deleteMedicine,
  logMedicationAction,
  getMedicationLogs,
};
