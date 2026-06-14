import 'package:carelanka_app/services/reminder_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportService {
  ReportService({ReminderService? reminderService})
      : _reminderService = reminderService ?? ReminderService();

  final ReminderService _reminderService;

  Future<double> adherencePercent(String userId, {DateTime? start, DateTime? end}) {
    return _reminderService.calculateAdherencePercent(userId, start: start, end: end);
  }

  Future<DoseStats> fetchDoseStats(String userId, {DateTime? start, DateTime? end}) {
    return _reminderService.fetchDoseStats(userId, start: start, end: end);
  }

  Future<void> generateAndSharePdf({
    required String userName,
    required double adherencePercent,
    required String periodLabel,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('CareLanka Health Report', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.Text('Patient: $userName'),
            pw.Text('Period: $periodLabel'),
            pw.SizedBox(height: 16),
            pw.Text('Adherence: ${adherencePercent.toStringAsFixed(1)}%'),
            pw.SizedBox(height: 12),
            pw.Text('Generated on ${DateTime.now()}'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }
}
