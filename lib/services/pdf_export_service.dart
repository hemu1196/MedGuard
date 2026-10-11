import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../models/appointment.dart';
import '../models/health_record.dart';

class PdfExportService {
  static final PdfExportService _instance = PdfExportService._internal();
  factory PdfExportService() => _instance;
  PdfExportService._internal();

  /// Converts an image (Uint8List) into a formatted A4 PDF
  Future<Uint8List> convertImageToPdf({
    required Uint8List imageBytes,
    required String title,
    String? recordDate,
    String? patientName,
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'MEDGUARD Health Management System',
    );

    final image = pw.MemoryImage(imageBytes);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MEDGUARD HEALTH VAULT',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal800,
                        ),
                      ),
                      pw.Text(
                        'Official Exported Health Document',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Divider(thickness: 1, color: PdfColors.teal),
              pw.SizedBox(height: 8),

              // Metadata
              pw.Text(
                'Document: $title',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (recordDate != null)
                pw.Text('Date of Record: $recordDate', style: const pw.TextStyle(fontSize: 11)),
              if (patientName != null && patientName.isNotEmpty)
                pw.Text('Patient: $patientName', style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 16),

              // Image content
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(image, fit: pw.BoxFit.contain),
                ),
              ),

              pw.SizedBox(height: 12),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Center(
                child: pw.Text(
                  'CONFIDENTIAL MEDICAL RECORD - Protected by MEDGUARD Secure Health Vault',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Generates a professional MEDGUARD-branded A4 PDF summary for an Appointment
  Future<Uint8List> generateAppointmentPdf({
    required Appointment appointment,
    String? patientName,
  }) async {
    final pdf = pw.Document(
      title: 'Appointment Summary - ${appointment.doctorName}',
      author: 'MEDGUARD Health System',
    );

    final appointmentDateStr = DateFormat('EEEE, MMMM d, yyyy').format(appointment.appointmentDate);
    final appointmentTimeStr = DateFormat('hh:mm a').format(appointment.appointmentDate);
    final generatedAtStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Brand Banner
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MEDGUARD',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Smart Health Emergency Assistance & Health Management System',
                          style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.teal900,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'PERSONAL APPOINTMENT RECORD',
                        style: pw.TextStyle(
                          color: PdfColors.teal100,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Title & Reference
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Appointment Summary',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                  ),
                  pw.Text(
                    'Ref ID: ${appointment.id.length > 8 ? appointment.id.substring(appointment.id.length - 8).toUpperCase() : appointment.id.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Text(
                'Generated on: $generatedAtStr',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
              ),

              pw.SizedBox(height: 16),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Consultation Details Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  _buildTableRow('Patient Name', patientName ?? 'Authorized User'),
                  _buildTableRow('Consulting Doctor', 'Dr. ${appointment.doctorName}'),
                  _buildTableRow('Specialty', appointment.specialty),
                  _buildTableRow('Hospital / Clinic', appointment.hospitalOrClinic.isNotEmpty ? appointment.hospitalOrClinic : 'Not Specified'),
                  _buildTableRow('Hospital Location', appointment.location.isNotEmpty ? appointment.location : 'Standard Clinic Location'),
                  _buildTableRow('Doctor / Clinic Phone', appointment.phoneNumber.isNotEmpty ? appointment.phoneNumber : 'Not Provided'),
                  _buildTableRow('Scheduled Date', appointmentDateStr),
                  _buildTableRow('Scheduled Time', appointmentTimeStr),
                  _buildTableRow('Status', appointment.statusText.toUpperCase()),
                ],
              ),

              pw.SizedBox(height: 16),

              // Notes & Purpose Section
              pw.Text(
                'Clinical Notes & Consultation Purpose:',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  appointment.notes.isNotEmpty ? appointment.notes : 'No specific consultation notes provided.',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
                ),
              ),

              pw.Spacer(),

              // Verification Note & Footer
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.amber50,
                  border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  children: [
                    pw.Text(
                      'Notice: ',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.amber900),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        'This document is a personal appointment record maintained by the user via MEDGUARD. Please carry this summary and arrive 15 minutes prior to the scheduled consultation.',
                        style: const pw.TextStyle(fontSize: 9, color: PdfColors.amber900),
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'MEDGUARD Smart Health Assistance | Private & Confidential',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.TableRow _buildTableRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: PdfColors.grey100,
          child: pw.Text(
            label,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
        ),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.black),
          ),
        ),
      ],
    );
  }

  /// Generates an A4 PDF summary for any health vault record
  Future<Uint8List> generateHealthRecordSummaryPdf({
    required HealthRecord record,
    String? patientName,
  }) async {
    final pdf = pw.Document(
      title: 'Health Vault Record - ${record.title}',
      author: 'MEDGUARD Health System',
    );

    final recordDateStr = DateFormat('EEEE, MMMM d, yyyy').format(record.documentDate);
    final generatedAtStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.teal800,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MEDGUARD HEALTH VAULT',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Verified Medical Record Summary',
                          style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10),
                        ),
                      ],
                    ),
                    pw.Text(
                      record.typeDisplayName.toUpperCase(),
                      style: pw.TextStyle(
                        color: PdfColors.teal100,
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    record.title,
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    'Record Date: $recordDateStr',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(thickness: 1, color: PdfColors.grey300),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  _buildTableRow('Record Category', record.typeDisplayName),
                  if (record.doctorName.isNotEmpty)
                    _buildTableRow('Doctor / Clinician', 'Dr. ${record.doctorName}'),
                  if (record.hospitalName.isNotEmpty)
                    _buildTableRow('Medical Facility', record.hospitalName),
                  if (record.providerName.isNotEmpty)
                    _buildTableRow('Provider', record.providerName),
                  _buildTableRow('Export Generated', generatedAtStr),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Clinical Notes & Extracted Details:',
                style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 6),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.Text(
                  record.description.isNotEmpty
                      ? record.description
                      : 'Clinical record securely archived in MEDGUARD vault.',
                  style: const pw.TextStyle(fontSize: 11),
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.Center(
                child: pw.Text(
                  'CONFIDENTIAL MEDICAL RECORD - MedGuard Smart Health Vault',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  /// Downloads or opens a print/save preview for the PDF
  Future<void> downloadPdf({
    required Uint8List bytes,
    required String filename,
  }) async {
    // Printing.layoutPdf prompts the user to download or print on Web,
    // and saves / prints on Android.
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: filename,
    );
  }

  /// Opens the native platform share sheet for the PDF
  Future<void> sharePdf({
    required Uint8List bytes,
    required String filename,
    String? subject,
  }) async {
    try {
      await Printing.sharePdf(
        bytes: bytes,
        filename: filename,
        subject: subject ?? 'MEDGUARD Health Document',
      );
    } catch (e) {
      debugPrint('[PDF EXPORT] Printing.sharePdf fallback to SharePlus: $e');
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: filename,
            mimeType: 'application/pdf',
          ),
        ],
        subject: subject ?? 'MEDGUARD Health Document',
      );
    }
  }
}
