const PDFDocument = require('pdfkit');
const fs = require('fs');
const path = require('path');
const { PDFS_DIR } = require('./storageService');

/**
 * Generate PDF Summary for an Appointment
 * @param {Object} appointment
 * @param {Object} user
 * @returns {Promise<string>} relative or absolute path to generated PDF
 */
const generateAppointmentPdf = (appointment, user) => {
  return new Promise((resolve, reject) => {
    try {
      const fileName = `Appointment_${appointment._id}.pdf`;
      const filePath = path.join(PDFS_DIR, fileName);

      const doc = new PDFDocument({ margin: 50 });
      const stream = fs.createWriteStream(filePath);

      doc.pipe(stream);

      // Header Banner
      doc.rect(0, 0, doc.page.width, 80).fill('#0284C7');
      doc.fillColor('#FFFFFF')
        .fontSize(22)
        .font('Helvetica-Bold')
        .text('MEDGUARD — APPOINTMENT SUMMARY', 50, 25);
      doc.fontSize(10)
        .font('Helvetica')
        .text('Smart Emergency Assistance & Health Management System', 50, 52);

      doc.moveDown(4);
      doc.fillColor('#1E293B');

      // Patient Details Box
      doc.fontSize(14).font('Helvetica-Bold').text('Patient Information', 50, 100);
      doc.rect(50, 118, doc.page.width - 100, 60).fillAndStroke('#F8FAFC', '#E2E8F0');
      
      doc.fillColor('#334155').fontSize(10).font('Helvetica');
      doc.text(`Name: ${user.fullName || 'N/A'}`, 65, 128);
      doc.text(`Email: ${user.email || 'N/A'}`, 65, 143);
      doc.text(`Phone: ${user.phoneNumber || 'N/A'}`, 65, 158);
      
      doc.text(`Age: ${user.age || 'N/A'}`, 300, 128);
      doc.text(`Gender: ${user.gender || 'N/A'}`, 300, 143);
      doc.text(`Blood Group: ${user.bloodGroup || 'N/A'}`, 300, 158);

      // Appointment Details Box
      doc.fontSize(14).font('Helvetica-Bold').fillColor('#1E293B').text('Appointment Details', 50, 195);
      doc.rect(50, 213, doc.page.width - 100, 120).fillAndStroke('#F1F5F9', '#CBD5E1');

      doc.fillColor('#0F172A').fontSize(11).font('Helvetica-Bold');
      doc.text(`Doctor: ${appointment.doctorName}`, 65, 225);
      doc.font('Helvetica').fontSize(10);
      doc.text(`Specialty: ${appointment.specialty}`, 65, 243);
      doc.text(`Hospital: ${appointment.hospitalName}`, 65, 260);

      const formattedDate = new Date(appointment.appointmentDate).toLocaleDateString('en-US', {
        weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
      });
      doc.text(`Date: ${formattedDate}`, 300, 225);
      doc.text(`Time: ${appointment.appointmentTime}`, 300, 243);
      doc.text(`Status: ${appointment.status.toUpperCase()}`, 300, 260);

      if (appointment.reason) {
        doc.fontSize(10).font('Helvetica-Oblique').fillColor('#475569');
        doc.text(`Reason for Visit: ${appointment.reason}`, 65, 285);
      }

      // Notes Section
      if (appointment.notes) {
        doc.fontSize(14).font('Helvetica-Bold').fillColor('#1E293B').text('Doctor / Clinical Notes', 50, 355);
        doc.rect(50, 373, doc.page.width - 100, 80).stroke('#CBD5E1');
        doc.fillColor('#334155').fontSize(10).font('Helvetica').text(appointment.notes, 65, 385, { width: doc.page.width - 130 });
      }

      // Footer
      doc.fontSize(9).font('Helvetica-Oblique').fillColor('#64748B')
        .text('Generated automatically by MEDGUARD Health Management System.', 50, doc.page.height - 50, { align: 'center' });

      doc.end();

      stream.on('finish', () => {
        resolve(filePath);
      });

      stream.on('error', (err) => {
        reject(err);
      });
    } catch (err) {
      reject(err);
    }
  });
};

module.exports = {
  generateAppointmentPdf,
};
