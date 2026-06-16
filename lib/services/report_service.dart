import 'dart:typed_data';

import 'package:carelanka_app/core/firebase/firebase_collections.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// One row in the breakdown table (day / week / month depending on period).
class DailyBreakdown {
  const DailyBreakdown({
    required this.date,
    required this.score,
    required this.confirmed,
    required this.total,
  });

  final DateTime date;
  final double score;
  final int confirmed;
  final int total;
}

/// Aggregated report data returned by every period getter.
class ReportData {
  const ReportData({
    required this.adherenceScore,
    required this.confirmed,
    required this.missed,
    required this.skipped,
    required this.pending,
    required this.total,
    required this.insightText,
    required this.breakdown,
    required this.periodLabel,
  });

  final double adherenceScore;
  final int confirmed;
  final int missed;
  final int skipped;
  final int pending;
  final int total;
  final String insightText;
  final List<DailyBreakdown> breakdown;
  final String periodLabel;

  bool get isEmpty => total == 0;

  /// Convenience: returns a [DoseStats] for screens that already use that type.
  DoseStats toDoseStats() => DoseStats(
        taken: confirmed,
        missed: missed + skipped,
        pending: pending,
        total: total,
        medStats: const [],
      );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

class ReportService {
  ReportService({
    FirebaseFirestore? firestore,
    ReminderService? reminderService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _reminderService = reminderService ?? ReminderService();

  final FirebaseFirestore _firestore;
  final ReminderService _reminderService;

  // Keep the existing thin wrappers so the current screen compiles unchanged.
  Future<double> adherencePercent(String userId,
          {DateTime? start, DateTime? end}) =>
      _reminderService.calculateAdherencePercent(userId,
          start: start, end: end);

  Future<DoseStats> fetchDoseStats(String userId,
          {DateTime? start, DateTime? end}) =>
      _reminderService.fetchDoseStats(userId, start: start, end: end);

  // ---------------------------------------------------------------------------
  // Period reports
  // ---------------------------------------------------------------------------

  Future<ReportData> getDailyReport(String userId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _buildReport(
      userId: userId,
      start: start,
      end: end,
      periodLabel: DateFormat('d MMM yyyy').format(date),
      groupBy: _GroupBy.day,
    );
  }

  Future<ReportData> getWeeklyReport(
      String userId, DateTime weekStart) async {
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    final label =
        '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end.subtract(const Duration(days: 1)))}';
    return _buildReport(
      userId: userId,
      start: start,
      end: end,
      periodLabel: label,
      groupBy: _GroupBy.day,
    );
  }

  Future<ReportData> getMonthlyReport(
      String userId, int month, int year) async {
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 1);
    return _buildReport(
      userId: userId,
      start: start,
      end: end,
      periodLabel: DateFormat('MMMM yyyy').format(start),
      groupBy: _GroupBy.week,
    );
  }

  Future<ReportData> getYearlyReport(String userId, int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    return _buildReport(
      userId: userId,
      start: start,
      end: end,
      periodLabel: '$year',
      groupBy: _GroupBy.month,
    );
  }

  // ---------------------------------------------------------------------------
  // PDF generation
  // ---------------------------------------------------------------------------

  /// Generates a rich PDF report and opens the platform share / print dialog.
  Future<void> generateAndSharePdf({
    required String userName,
    required double adherencePercent,
    required String periodLabel,
    // Optional — enriches the PDF with breakdown table and insight text.
    ReportData? reportData,
  }) async {
    final data = reportData;
    final bytes = await generatePdf(
      data: data ??
          ReportData(
            adherenceScore: adherencePercent,
            confirmed: 0,
            missed: 0,
            skipped: 0,
            pending: 0,
            total: 0,
            insightText: '',
            breakdown: const [],
            periodLabel: periodLabel,
          ),
      userName: userName,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  /// Builds the PDF document and returns raw bytes.
  Future<Uint8List> generatePdf({
    required ReportData data,
    required String userName,
  }) async {
    final doc = pw.Document();

    // Colour palette
    const navy = PdfColor.fromInt(0xFF001F5F);
    const teal = PdfColor.fromInt(0xFF00A8A8);
    const green = PdfColor.fromInt(0xFF2DC653);
    const red = PdfColor.fromInt(0xFFE53935);
    const grey = PdfColor.fromInt(0xFF757575);
    const lightGrey = PdfColor.fromInt(0xFFF7F8FA);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: grey),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Generated by CareLanka',
                    style: pw.TextStyle(fontSize: 9, color: grey)),
                pw.Text(
                    'This report is for informational purposes only.',
                    style: pw.TextStyle(fontSize: 9, color: grey)),
              ],
            ),
          ],
        ),
        build: (ctx) => [
          // ── Header ──────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: navy,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CareLanka Health Report',
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Patient: $userName',
                        style: pw.TextStyle(
                            fontSize: 12, color: const PdfColor.fromInt(0xFFB0C4DE))),
                    pw.Text('Period: ${data.periodLabel}',
                        style: pw.TextStyle(
                            fontSize: 12, color: const PdfColor.fromInt(0xFFB0C4DE))),
                    pw.Text(
                        'Generated: ${DateFormat('d MMM yyyy, h:mm a').format(DateTime.now())}',
                        style: pw.TextStyle(
                            fontSize: 10, color: const PdfColor.fromInt(0xFF8899BB))),
                  ],
                ),
                // Large adherence circle
                pw.Container(
                  width: 72,
                  height: 72,
                  decoration: pw.BoxDecoration(
                    color: teal,
                    shape: pw.BoxShape.circle,
                  ),
                  alignment: pw.Alignment.center,
                  child: pw.Text(
                    '${data.adherenceScore.round()}%',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 20),

          // ── Stats row ────────────────────────────────────────────────────
          pw.Row(
            children: [
              _statBox('Confirmed', data.confirmed, green),
              pw.SizedBox(width: 8),
              _statBox('Missed', data.missed, red),
              pw.SizedBox(width: 8),
              _statBox('Skipped', data.skipped, grey),
              pw.SizedBox(width: 8),
              _statBox('Total', data.total, navy),
            ],
          ),
          pw.SizedBox(height: 20),

          // ── Insight ──────────────────────────────────────────────────────
          if (data.insightText.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE8F4FC),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CareLanka Insights',
                      style: pw.TextStyle(
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 13,
                          color: navy)),
                  pw.SizedBox(height: 6),
                  pw.Text(data.insightText,
                      style:
                          pw.TextStyle(fontSize: 12, color: PdfColors.blueGrey800)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // ── Breakdown table ──────────────────────────────────────────────
          if (data.breakdown.isNotEmpty) ...[
            pw.Text('Medication Breakdown',
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: navy)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Confirmed', 'Missed', 'Total', 'Score'],
              headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 11),
              headerDecoration:
                  const pw.BoxDecoration(color: navy),
              oddRowDecoration:
                  const pw.BoxDecoration(color: lightGrey),
              cellStyle: pw.TextStyle(fontSize: 11),
              cellAlignment: pw.Alignment.center,
              data: data.breakdown.map((b) {
                final missed = b.total - b.confirmed;
                return [
                  DateFormat('d MMM').format(b.date),
                  '${b.confirmed}',
                  '$missed',
                  '${b.total}',
                  '${b.score.round()}%',
                ];
              }).toList(),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _statBox(String label, int value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color),
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              '$value',
              style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: color),
            ),
            pw.SizedBox(height: 4),
            pw.Text(label,
                style: pw.TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Internal query + grouping
  // ---------------------------------------------------------------------------

  Future<ReportData> _buildReport({
    required String userId,
    required DateTime start,
    required DateTime end,
    required String periodLabel,
    required _GroupBy groupBy,
  }) async {
    try {
      final snap = await _firestore
          .collection(FirebaseCollections.reminderLogs)
          .where('userId', isEqualTo: userId)
          .where('scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('scheduledTime', isLessThan: Timestamp.fromDate(end))
          .get();

      var confirmed = 0;
      var missed = 0;
      var skipped = 0;

      // Group key → {confirmed, total}
      final groups = <String, _GroupBucket>{};

      for (final doc in snap.docs) {
        final d = doc.data();
        final status = (d['status'] as String? ?? '').toLowerCase();
        final scheduledRaw = d['scheduledTime'];
        if (scheduledRaw is! Timestamp) continue;
        final dt = scheduledRaw.toDate();

        if (status == 'confirmed' || status == 'taken') {
          confirmed++;
        } else if (status == 'missed') {
          missed++;
        } else if (status == 'skipped') {
          skipped++;
        }

        final key = _groupKey(dt, groupBy);
        groups.putIfAbsent(key, () => _GroupBucket(date: _groupDate(dt, groupBy)));
        groups[key]!.total++;
        if (status == 'confirmed' || status == 'taken') groups[key]!.confirmed++;
      }

      final total = confirmed + missed + skipped;
      final score = total > 0 ? (confirmed / total) * 100 : 100.0;
      final insight = AdherenceService().generateInsightText(score);

      final breakdown = groups.entries.map((e) {
        final b = e.value;
        final s = b.total > 0 ? (b.confirmed / b.total) * 100 : 100.0;
        return DailyBreakdown(
          date: b.date,
          score: s,
          confirmed: b.confirmed,
          total: b.total,
        );
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      return ReportData(
        adherenceScore: score,
        confirmed: confirmed,
        missed: missed,
        skipped: skipped,
        pending: 0,
        total: total,
        insightText: insight,
        breakdown: breakdown,
        periodLabel: periodLabel,
      );
    } catch (_) {
      return ReportData(
        adherenceScore: 0,
        confirmed: 0,
        missed: 0,
        skipped: 0,
        pending: 0,
        total: 0,
        insightText: '',
        breakdown: const [],
        periodLabel: periodLabel,
      );
    }
  }

  String _groupKey(DateTime dt, _GroupBy groupBy) {
    switch (groupBy) {
      case _GroupBy.day:
        return '${dt.year}-${dt.month}-${dt.day}';
      case _GroupBy.week:
        // ISO week number approximation
        final weekOfMonth = ((dt.day - 1) ~/ 7) + 1;
        return '${dt.year}-${dt.month}-w$weekOfMonth';
      case _GroupBy.month:
        return '${dt.year}-${dt.month}';
    }
  }

  DateTime _groupDate(DateTime dt, _GroupBy groupBy) {
    switch (groupBy) {
      case _GroupBy.day:
        return DateTime(dt.year, dt.month, dt.day);
      case _GroupBy.week:
        final weekOfMonth = ((dt.day - 1) ~/ 7);
        return DateTime(dt.year, dt.month, weekOfMonth * 7 + 1);
      case _GroupBy.month:
        return DateTime(dt.year, dt.month, 1);
    }
  }
}

enum _GroupBy { day, week, month }

class _GroupBucket {
  _GroupBucket({required this.date});
  final DateTime date;
  int confirmed = 0;
  int total = 0;
}
