const fs = require('fs');
const Appointment = require('../models/Appointment');
const { generateAppointmentPdf } = require('../services/pdfService');

const getAppointments = async (req, res) => {
  try {
    const appointments = await Appointment.find({ userId: req.userId }).sort({ appointmentDate: 1 });
    return res.status(200).json({
      success: true,
      appointments,
    });
  } catch (error) {
    console.error('Get Appointments Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to fetch appointments.',
    });
  }
};

const addAppointment = async (req, res) => {
  try {
    const { doctorName, specialty, hospitalName, appointmentDate, appointmentTime, reason, notes } = req.body;

    if (!doctorName || !hospitalName || !appointmentDate || !appointmentTime) {
      return res.status(400).json({
        success: false,
        message: 'Doctor name, hospital name, date, and time are required.',
      });
    }

    const appointment = new Appointment({
      userId: req.userId,
      doctorName,
      specialty: specialty || 'General Physician',
      hospitalName,
      appointmentDate: new Date(appointmentDate),
      appointmentTime,
      reason: reason || '',
      notes: notes || '',
      status: 'upcoming',
    });

    await appointment.save();

    // Auto-generate PDF Summary
    try {
      const pdfPath = await generateAppointmentPdf(appointment, req.user);
      appointment.pdfPath = pdfPath;
      await appointment.save();
    } catch (pdfErr) {
      console.warn('Failed to auto-generate PDF summary:', pdfErr.message);
    }

    return res.status(201).json({
      success: true,
      message: 'Appointment booked successfully.',
      appointment,
    });
  } catch (error) {
    console.error('Add Appointment Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to add appointment. ' + error.message,
    });
  }
};

const updateAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const appointment = await Appointment.findOne({ _id: appointmentId, userId: req.userId });

    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: 'Appointment not found.',
      });
    }

    const updates = req.body;
    Object.keys(updates).forEach((key) => {
      if (key !== 'userId' && key !== '_id') {
        appointment[key] = updates[key];
      }
    });

    await appointment.save();

    // Re-generate PDF Summary
    try {
      const pdfPath = await generateAppointmentPdf(appointment, req.user);
      appointment.pdfPath = pdfPath;
      await appointment.save();
    } catch (pdfErr) {
      console.warn('Failed to regenerate PDF summary:', pdfErr.message);
    }

    return res.status(200).json({
      success: true,
      message: 'Appointment updated successfully.',
      appointment,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to update appointment.',
    });
  }
};

const downloadAppointmentPdf = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const appointment = await Appointment.findOne({ _id: appointmentId, userId: req.userId });

    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: 'Appointment not found.',
      });
    }

    let filePath = appointment.pdfPath;
    if (!filePath || !fs.existsSync(filePath)) {
      filePath = await generateAppointmentPdf(appointment, req.user);
      appointment.pdfPath = filePath;
      await appointment.save();
    }

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Disposition', `inline; filename="Appointment_${appointment._id}.pdf"`);
    fs.createReadStream(filePath).pipe(res);
  } catch (error) {
    console.error('Download Appointment PDF Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to generate or download appointment PDF.',
    });
  }
};

const deleteAppointment = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const appointment = await Appointment.findOne({ _id: appointmentId, userId: req.userId });

    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: 'Appointment not found.',
      });
    }

    if (appointment.pdfPath && fs.existsSync(appointment.pdfPath)) {
      try {
        fs.unlinkSync(appointment.pdfPath);
      } catch (err) {}
    }

    await Appointment.deleteOne({ _id: appointmentId });

    return res.status(200).json({
      success: true,
      message: 'Appointment deleted successfully.',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Failed to delete appointment.',
    });
  }
};

const patchAppointmentStatus = async (req, res) => {
  try {
    const { appointmentId } = req.params;
    const { status } = req.body;

    if (!status || typeof status !== 'string') {
      return res.status(400).json({
        success: false,
        message: 'Status is required.',
      });
    }

    const validStatuses = ['upcoming', 'completed', 'cancelled'];
    const normalized = status.toLowerCase().trim();
    if (!validStatuses.includes(normalized)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status "${status}". Must be one of: upcoming, completed, cancelled.`,
      });
    }

    const appointment = await Appointment.findOne({ _id: appointmentId, userId: req.userId });
    if (!appointment) {
      return res.status(404).json({
        success: false,
        message: 'Appointment not found.',
      });
    }

    appointment.status = normalized;
    await appointment.save();

    return res.status(200).json({
      success: true,
      message: `Appointment marked as ${normalized}.`,
      appointment,
    });
  } catch (error) {
    console.error('Patch Appointment Status Error:', error);
    return res.status(500).json({
      success: false,
      message: 'Failed to update appointment status: ' + error.message,
    });
  }
};

module.exports = {
  getAppointments,
  addAppointment,
  updateAppointment,
  patchAppointmentStatus,
  downloadAppointmentPdf,
  deleteAppointment,
};
