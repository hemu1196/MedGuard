const mongoose = require('mongoose');

const appointmentSchema = new mongoose.Schema({
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  doctorName: {
    type: String,
    required: true,
    trim: true,
  },
  specialty: {
    type: String,
    default: 'General Physician',
    trim: true,
  },
  hospitalName: {
    type: String,
    required: true,
    trim: true,
  },
  appointmentDate: {
    type: Date,
    required: true,
  },
  appointmentTime: {
    type: String, // e.g. "10:30 AM"
    required: true,
  },
  reason: {
    type: String,
    default: '',
  },
  status: {
    type: String,
    enum: ['upcoming', 'completed', 'cancelled'],
    default: 'upcoming',
  },
  notes: {
    type: String,
    default: '',
  },
  pdfPath: {
    type: String,
    default: null,
  },
}, {
  timestamps: true,
});

module.exports = mongoose.model('Appointment', appointmentSchema);
