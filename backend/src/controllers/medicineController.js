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
    console.error('Get Medicines Error:', error);
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
    console.error('Add Medicine Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to add medicine. ' + error.message,
    });
  }
};

const updateMedicine = async (req, res) => {
  try {
    const { medicineId } = req.params;
    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });

    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    const updates = req.body;
    Object.keys(updates).forEach((key) => {
      if (key !== 'userId' && key !== '_id') {
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
    console.error('Update Medicine Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update medicine. ' + error.message,
    });
  }
};

const deleteMedicine = async (req, res) => {
  try {
    const { medicineId } = req.params;
    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });

    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    medicine.isActive = false;
    await medicine.save();

    return res.status(200).json({
      success: true,
      message: 'Medicine removed successfully.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to delete medicine.',
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

    const medicine = await Medicine.findOne({ _id: medicineId, userId: req.userId });
    if (!medicine) {
      return res.status(404).json({
        success: false,
        message: 'Medicine not found.',
      });
    }

    // Deduct stock if taken
    if (status === 'taken') {
      if (medicine.remainingStock > 0) {
        medicine.remainingStock -= 1;
        await medicine.save();
      }
    }

    const logEntry = new MedicationLog({
      userId: req.userId,
      medicineId: medicine._id,
      medicineName: medicine.name,
      dosage: medicine.dosage,
      scheduledTime,
      status,
      takenAt: status === 'taken' ? new Date() : null,
      missedReason: missedReason || '',
    });

    await logEntry.save();

    return res.status(200).json({
      success: true,
      message: `Medication marked as ${status}.`,
      remainingStock: medicine.remainingStock,
      log: logEntry,
    });
  } catch (error) {
    console.error('Log Medication Action Error:', error);
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
