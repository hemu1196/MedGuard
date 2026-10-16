const mongoose = require('mongoose');
const HealthRecord = require('../models/HealthRecord');
const { uploadToVault, getDownloadStream, deleteFromVault } = require('../services/storageService');

/**
 * Get all health records for authenticated user
 */
const getRecords = async (req, res) => {
  try {
    const { category, type } = req.query;
    const filter = { userId: req.userId };

    const targetCategory = category || type;
    if (targetCategory && targetCategory !== 'all') {
      filter.$or = [
        { category: targetCategory },
        { recordType: targetCategory },
      ];
    }

    const records = await HealthRecord.find(filter).sort({ documentDate: -1, createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: records.length,
      records: records.map((r) => r.toJSON()),
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Get Records Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch health records.',
    });
  }
};

/**
 * Get single health record by ID
 */
const getRecordById = async (req, res) => {
  try {
    const { recordId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(recordId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid health record ID format.',
      });
    }

    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });
    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found or unauthorized.',
      });
    }

    return res.status(200).json({
      success: true,
      record: record.toJSON(),
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Get Record By ID Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to retrieve health record.',
    });
  }
};

/**
 * Create a new metadata/note-only health record (without file attachment)
 */
const createRecord = async (req, res) => {
  try {
    const { title, category, recordType, doctorName, hospitalName, documentDate, tags, notes } = req.body;

    if (!title || typeof title !== 'string' || title.trim().length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Record title is required.',
      });
    }

    let tagList = [];
    if (tags) {
      tagList = Array.isArray(tags) ? tags : String(tags).split(',').map((t) => t.trim()).filter(Boolean);
    }

    const record = new HealthRecord({
      userId: req.userId,
      title: title.trim(),
      category: category || 'other',
      recordType: recordType || category || 'other',
      doctorName: doctorName ? String(doctorName).trim() : '',
      hospitalName: hospitalName ? String(hospitalName).trim() : '',
      documentDate: documentDate ? new Date(documentDate) : new Date(),
      storageType: 'none',
      storageKey: null,
      filePath: null,
      fileName: '',
      mimeType: '',
      fileSizeBytes: 0,
      tags: tagList,
      notes: notes ? String(notes).trim() : '',
    });

    await record.save();

    return res.status(201).json({
      success: true,
      message: 'Health record created successfully.',
      record: record.toJSON(),
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Create Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to create health record: ' + error.message,
    });
  }
};

/**
 * Upload and persist health record with document/image attachment to MongoDB GridFS
 */
const uploadRecord = async (req, res) => {
  let uploadedStorage = null;

  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file attachment was provided in the upload request.',
      });
    }

    const { title, category, recordType, doctorName, hospitalName, documentDate, tags, notes } = req.body;

    const resolvedTitle = (title || req.file.originalname || 'Medical Document').trim();

    // 1. Persist file into permanent private storage (MongoDB Atlas GridFS)
    uploadedStorage = await uploadToVault({
      file: req.file,
      userId: req.userId,
      title: resolvedTitle,
    });

    let tagList = [];
    if (tags) {
      tagList = Array.isArray(tags) ? tags : String(tags).split(',').map((t) => t.trim()).filter(Boolean);
    }

    // 2. Persist record document into MongoDB Atlas
    const record = new HealthRecord({
      userId: req.userId,
      title: resolvedTitle,
      category: category || 'other',
      recordType: recordType || category || 'other',
      doctorName: doctorName ? String(doctorName).trim() : '',
      hospitalName: hospitalName ? String(hospitalName).trim() : '',
      documentDate: documentDate ? new Date(documentDate) : new Date(),
      storageKey: uploadedStorage.storageKey,
      storageType: uploadedStorage.storageType,
      fileName: uploadedStorage.fileName,
      mimeType: uploadedStorage.mimeType,
      fileSizeBytes: uploadedStorage.fileSizeBytes,
      tags: tagList,
      notes: notes ? String(notes).trim() : '',
    });

    await record.save();

    return res.status(201).json({
      success: true,
      message: 'Health record and document uploaded successfully.',
      record: record.toJSON(),
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Upload Record Error:', error);

    // Rollback orphaned file if MongoDB document creation failed
    if (uploadedStorage && uploadedStorage.storageKey) {
      await deleteFromVault({
        storageKey: uploadedStorage.storageKey,
        storageType: uploadedStorage.storageType,
      }).catch((cleanupErr) => {
        console.warn('[STORAGE CLEANUP] Rollback error:', cleanupErr.message);
      });
    }

    return res.status(500).json({
      success: false,
      message: 'Failed to upload health record: ' + error.message,
    });
  }
};

/**
 * Update an existing health record metadata
 */
const updateRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(recordId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid health record ID format.',
      });
    }

    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });
    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found or unauthorized.',
      });
    }

    const { title, category, recordType, doctorName, hospitalName, documentDate, tags, notes } = req.body;

    if (title !== undefined && title.trim().length > 0) record.title = title.trim();
    if (category !== undefined) record.category = category;
    if (recordType !== undefined) record.recordType = recordType;
    if (doctorName !== undefined) record.doctorName = String(doctorName).trim();
    if (hospitalName !== undefined) record.hospitalName = String(hospitalName).trim();
    if (documentDate !== undefined) record.documentDate = new Date(documentDate);
    if (notes !== undefined) record.notes = String(notes).trim();

    if (tags !== undefined) {
      record.tags = Array.isArray(tags)
        ? tags
        : String(tags).split(',').map((t) => t.trim()).filter(Boolean);
    }

    // If new file attachment is provided during update
    if (req.file) {
      const oldStorageKey = record.storageKey;
      const oldStorageType = record.storageType;

      const uploadedStorage = await uploadToVault({
        file: req.file,
        userId: req.userId,
        title: record.title,
      });

      record.storageKey = uploadedStorage.storageKey;
      record.storageType = uploadedStorage.storageType;
      record.fileName = uploadedStorage.fileName;
      record.mimeType = uploadedStorage.mimeType;
      record.fileSizeBytes = uploadedStorage.fileSizeBytes;

      if (oldStorageKey) {
        await deleteFromVault({
          storageKey: oldStorageKey,
          storageType: oldStorageType,
        }).catch((err) => console.warn('[VAULT UPDATE] Old file cleanup note:', err.message));
      }
    }

    await record.save();

    return res.status(200).json({
      success: true,
      message: 'Health record updated successfully.',
      record: record.toJSON(),
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Update Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update health record: ' + error.message,
    });
  }
};

/**
 * Download/view authenticated medical file stream
 */
const downloadRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(recordId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid health record ID.',
      });
    }

    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });
    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found or unauthorized.',
      });
    }

    if (!record.storageKey && !record.filePath) {
      return res.status(404).json({
        success: false,
        message: 'This health record does not contain an attached document file.',
      });
    }

    const { stream, mimeType, fileName, fileSizeBytes } = await getDownloadStream(record);

    res.setHeader('Content-Type', mimeType);
    res.setHeader(
      'Content-Disposition',
      `inline; filename="${encodeURIComponent(fileName || 'document.pdf')}"`
    );
    if (fileSizeBytes > 0) {
      res.setHeader('Content-Length', fileSizeBytes);
    }

    stream.on('error', (streamErr) => {
      console.error('[STREAM ERROR] Download stream interrupted:', streamErr.message);
      if (!res.headersSent) {
        res.status(500).json({ success: false, message: 'Stream error reading file.' });
      }
    });

    stream.pipe(res);
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Download Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to download health record file: ' + error.message,
    });
  }
};

/**
 * Delete a health record and its associated private file from cloud storage
 */
const deleteRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    if (!mongoose.Types.ObjectId.isValid(recordId)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid health record ID.',
      });
    }

    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });
    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found or unauthorized.',
      });
    }

    // 1. Delete physical/GridFS file
    await deleteFromVault(record);

    // 2. Delete MongoDB metadata document
    await HealthRecord.deleteOne({ _id: recordId });

    return res.status(200).json({
      success: true,
      message: 'Health record and associated document deleted successfully.',
    });
  } catch (error) {
    console.error('[HEALTH RECORD CONTROLLER] Delete Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to delete health record.',
    });
  }
};

module.exports = {
  getRecords,
  getRecordById,
  createRecord,
  uploadRecord,
  updateRecord,
  downloadRecord,
  deleteRecord,
};
