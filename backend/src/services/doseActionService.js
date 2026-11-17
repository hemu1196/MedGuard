const crypto = require('crypto');
const Medicine = require('../models/Medicine');
const MedicationLog = require('../models/MedicationLog');

// Receipt and stock update share one atomic MongoDB pipeline, without requiring
// a replica-set transaction. A retried action repairs missing history safely.
async function recordDose({ userId, medicineId, scheduledTime, scheduledDate, status, missedReason = '' }) {
  const medicine = await Medicine.findOne({ _id: medicineId, userId });
  if (!medicine) return { status: 404, message: 'Medicine not found.' };
  const date = scheduledDate || new Date().toISOString().slice(0, 10);
  const parsedDate = new Date(date + 'T00:00:00Z');
  if (typeof date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(date) || !Number.isFinite(parsedDate.getTime()) || parsedDate.toISOString().slice(0, 10) !== date || !/^([01]\d|2[0-3]):[0-5]\d$/.test(scheduledTime)) return { status: 400, message: 'A valid dose date and HH:mm time are required.' };
  const occurrenceId = crypto.createHash('sha256').update(`${medicineId}|${date}|${scheduledTime}`).digest('hex');
  const at = new Date();
  const receipt = { occurrenceId, status, originalStatus:status, stockDebited:status==='taken'?Math.min(medicine.remainingStock,medicine.dosageQuantity||1):0, at };
  const changes = {
    doseReceipts: { $concatArrays: [{ $ifNull: ['$doseReceipts', []] }, [{ $mergeObjects: [{ $literal: receipt }, { stockDebited: status === 'taken' ? { $min: [{ $ifNull: ['$remainingStock', 0] }, medicine.dosageQuantity || 1] } : 0 }] }]] },
  };
  if (status === 'taken') changes.remainingStock = { $max: [0, { $subtract: [{ $ifNull: ['$remainingStock', 0] }, medicine.dosageQuantity || 1] }] };
  const updated = await Medicine.findOneAndUpdate({ _id: medicineId, userId, $or: [{ scheduleVersion: medicine.scheduleVersion || 1 }, { scheduleVersion: { $exists: false } }], 'doseReceipts.occurrenceId': { $ne: occurrenceId } }, [{ $set: changes }], { new: true });
  const current = updated || await Medicine.findOne({ _id: medicineId, userId });
  if (!current) return { status: 404, message: 'Medicine not found.' };
  const existing = current.doseReceipts.find(r => r.occurrenceId === occurrenceId);
  if (!existing) return { status: 409, message: 'Schedule changed. Refresh before recording this dose.' };
  if (existing.status !== status) return { status: 409, message: 'This dose already has a different recorded action. No stock was changed.' };
  let log;
  try { log = await MedicationLog.findOneAndUpdate({ userId, occurrenceId }, { $setOnInsert: {
    medicineId, medicineName: medicine.name, dosage: medicine.dosage,
    scheduledTime, scheduledDate: date, status, takenAt: status === 'taken' ? existing.at : null,
    missedReason: typeof missedReason === 'string' ? missedReason.slice(0, 1000) : '',
  } }, { upsert: true, new: true, runValidators: true });
  } catch (error) {
    if (error.code !== 11000) throw error;
    log = await MedicationLog.findOne({ userId, occurrenceId });
  }
  return { status: 200, success: true, message: `Medication marked as ${status}.`, remainingStock: current.remainingStock, duplicate: !updated, log };
}
module.exports = { recordDose };
