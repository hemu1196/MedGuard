const fs = require('fs');
const path = require('path');
const HealthRecord = require('../models/HealthRecord');

const getRecords = async (req, res) => {
  try {
    const { category } = req.query;
    const filter = { userId: req.userId };
    if (category) {
      filter.category = category;
    }

    const records = await HealthRecord.find(filter).sort({ createdAt: -1 });
    return res.status(200).json({
      success: true,
      records,
    });
  } catch (error) {
    console.error('Get Health Records Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch health records.',
    });
  }
};

const uploadRecord = async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No file uploaded.',
      });
    }

    const { title, category, tags, notes } = req.body;
    let tagList = [];
    if (tags) {
      tagList = Array.isArray(tags) ? tags : tags.split(',').map((t) => t.trim());
    }

    const record = new HealthRecord({
      userId: req.userId,
      title: title || req.file.originalname,
      category: category || 'other',
      filePath: req.file.path,
      fileName: req.file.originalname,
      mimeType: req.file.mimetype,
      fileSizeBytes: req.file.size,
      tags: tagList,
      notes: notes || '',
    });

    await record.save();

    return res.status(201).json({
      success: true,
      message: 'Health record uploaded successfully.',
      record,
    });
  } catch (error) {
    console.error('Upload Health Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to upload health record. ' + error.message,
    });
  }
};

const downloadRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });

    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found.',
      });
    }

    if (!fs.existsSync(record.filePath)) {
      return res.status(404).json({
        success: false,
        message: 'File content missing from server storage.',
      });
    }

    res.setHeader('Content-Type', record.mimeType);
    res.setHeader('Content-Disposition', `inline; filename="${record.fileName}"`);
    const fileStream = fs.createReadStream(record.filePath);
    fileStream.pipe(res);
  } catch (error) {
    console.error('Download Health Record Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to download health record.',
    });
  }
};

const deleteRecord = async (req, res) => {
  try {
    const { recordId } = req.params;
    const record = await HealthRecord.findOne({ _id: recordId, userId: req.userId });

    if (!record) {
      return res.status(404).json({
        success: false,
        message: 'Health record not found.',
      });
    }

    // Unlink physical file
    if (fs.existsSync(record.filePath)) {
      try {
        fs.unlinkSync(record.filePath);
      } catch (err) {
        console.warn('Could not unlink physical file:', err.message);
      }
    }

    await HealthRecord.deleteOne({ _id: recordId });

    return res.status(200).json({
      success: true,
      message: 'Health record deleted successfully.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to delete health record.',
    });
  }
};

module.exports = {
  getRecords,
  uploadRecord,
  downloadRecord,
  deleteRecord,
};
