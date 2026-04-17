import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared/models/incident.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateBrief(Incident incident) async {
    final doc = pw.Document();

    final formatter = DateFormat('MMM dd, yyyy - HH:mm:ss');
    final creationTime = formatter.format(DateTime.fromMillisecondsSinceEpoch(incident.createdAt));

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
              pw.SizedBox(height: 24),

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

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'Responder_Brief_${incident.id}.pdf',
    );
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
