// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared/models/incident.dart';
import 'package:intl/intl.dart';

class PdfService {
  /// Generates an in-memory PDF, creates a browser blob URL, and opens it in
  /// a new tab. Returns the URL so the caller can offer a "Copy Link" action.
  static Future<String> generateBriefUrl(Incident incident) async {
    final doc = pw.Document();

    final formatter = DateFormat('MMM dd, yyyy - HH:mm:ss');
    final creationTime = formatter.format(DateTime.fromMillisecondsSinceEpoch(incident.createdAt));

    pw.MemoryImage? attachedImage;
    if (incident.imageUrl != null && incident.imageUrl!.isNotEmpty) {
      try {
        print('[PdfService] Fetching image for PDF brief...');
        if (incident.imageUrl!.startsWith('data:image')) {
          final base64String = incident.imageUrl!.split(',').last;
          final imageBytes = base64Decode(base64String);
          attachedImage = pw.MemoryImage(imageBytes);
          print('[PdfService] Successfully loaded Base64 image into PDF memory.');
        } else {
          final ref = FirebaseStorage.instance.refFromURL(incident.imageUrl!);
          final imageBytes = await ref.getData(10 * 1024 * 1024); // 10MB limit
          if (imageBytes != null) {
            attachedImage = pw.MemoryImage(imageBytes);
            print('[PdfService] Successfully loaded Firebase incident image into PDF memory.');
          }
        }
      } catch (e) {
        print('[PdfService] Failed to load incident image for PDF: $e');
      }
    }

    PdfColor severityColor;
    switch (incident.severity) {
      case 5: severityColor = PdfColors.red900; break;
      case 4: severityColor = PdfColors.orange800; break;
      case 3: severityColor = PdfColors.amber700; break;
      case 2: severityColor = PdfColors.lightBlue700; break;
      default: severityColor = PdfColors.grey700; break;
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // HEADER
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: incident.status == IncidentStatus.escalated ? PdfColors.red900 : PdfColors.blueGrey900,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CRISISNET RESPONDER BRIEF',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'CONFIDENTIAL - FOR AUTHORIZED EMERGENCY PERSONNEL ONLY',
                      style: pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              
              if (incident.responderPin != null) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange100,
                    border: pw.Border.all(color: PdfColors.orange800, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(
                        'LIVE INCIDENT PORTAL & CHAT',
                        style: pw.TextStyle(color: PdfColors.orange900, fontWeight: pw.FontWeight.bold, fontSize: 14),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'URL: crisisnet.app/#/responder   |   ACCESS PIN: ${incident.responderPin}',
                        style: pw.TextStyle(color: PdfColors.black, fontWeight: pw.FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ],

              // INCIDENT METADATA
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildInfoCard('INCIDENT ID', incident.id.toUpperCase()),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _buildInfoCard('TIMESTAMP', creationTime),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildInfoCard('EMERGENCY TYPE', incident.type.name.toUpperCase()),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _buildInfoCard(
                      'SEVERITY LEVEL', 
                      'LEVEL ${incident.severity}', 
                      textColor: severityColor,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: _buildInfoCard('AFFECTED ZONE', incident.affectedZone),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: _buildInfoCard('GUEST COUNT', '${incident.guestCount} PERSON(S)'),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),

              // STATUS
              if (incident.status == IncidentStatus.escalated) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red100,
                    border: pw.Border.all(color: PdfColors.red900, width: 2),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'WARNING: ',
                        style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'THIS INCIDENT HAS BEEN ESCALATED TO EXTERNAL EMERGENCY SERVICES.',
                        style: const pw.TextStyle(color: PdfColors.red900),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ],

              // MEDICAL PROFILE
              if (incident.medicalInfo != null) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.red50,
                    border: pw.Border(left: pw.BorderSide(color: PdfColors.red900, width: 6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MEDICAL PROFILE (ANONYMOUS)',
                        style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold, fontSize: 14),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Blood Type: ${incident.medicalInfo!['bloodType'] ?? 'Unknown'}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('Height: ${incident.medicalInfo!['height'] ?? 'N/A'}    |    Weight: ${incident.medicalInfo!['weight'] ?? 'N/A'}'),
                      if ((incident.medicalInfo!['allergies'] ?? '').isNotEmpty)
                        pw.Text('Allergies: ${incident.medicalInfo!['allergies']}', style: pw.TextStyle(color: PdfColors.red900)),
                      if ((incident.medicalInfo!['conditions'] ?? '').isNotEmpty)
                        pw.Text('Conditions: ${incident.medicalInfo!['conditions']}', style: pw.TextStyle(color: PdfColors.orange900)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
              ],

              // EVIDENCE IMAGE
              if (attachedImage != null) ...[
                pw.Text(
                  'ATTACHED EVIDENCE',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
                ),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 200,
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Image(attachedImage),
                ),
                pw.SizedBox(height: 24),
              ],

              // TIMELINE LOG
              pw.Text(
                'AI EVENT TIMELINE',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
              ),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 8),
              
              ...incident.timeline.map((update) {
                final timeStr = formatter.format(DateTime.fromMillisecondsSinceEpoch(update.timestamp));
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 12),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 140,
                        child: pw.Text(
                          timeStr,
                          style: pw.TextStyle(color: PdfColors.grey600, fontSize: 10, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          update.updateText,
                          style: pw.TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              pw.Spacer(),

              // FOOTER
              pw.Center(
                child: pw.Text(
                  'GENERATED BY CRISISNET AI ENGINE - NOT FOR PUBLIC DISTRIBUTION',
                  style: pw.TextStyle(color: PdfColors.grey500, fontSize: 8),
                ),
              ),
            ],
          );
        },
      )
    );

    final pdfBytes = await doc.save();

    // Create an in-memory blob URL — no server needed, no popup-block risk.
    final blob = html.Blob([pdfBytes], 'application/pdf');
    final url = html.Url.createObjectUrl(blob);

    // Open the PDF in a new tab immediately
    html.window.open(url, '_blank');

    // Return URL so the caller can offer a "Copy Link" SnackBar action
    return url;
  }

  static pw.Widget _buildInfoCard(String title, String value, {PdfColor? textColor}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(color: PdfColors.grey600, fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textColor ?? PdfColors.black),
          ),
        ],
      ),
    );
  }
}
