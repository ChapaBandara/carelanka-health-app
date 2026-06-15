import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/services/report_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _tab = 0;
  DateTime _anchor = DateTime.now();
  final _reportService = ReportService();
  final _adherenceService = AdherenceService();

  (DateTime?, DateTime?) _periodRange() {
    switch (_tab) {
      case 0:
        final day = DateTime(_anchor.year, _anchor.month, _anchor.day);
        return (day, day.add(const Duration(days: 1)).subtract(const Duration(seconds: 1)));
      case 1:
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case 2:
        final start = DateTime(_anchor.year, _anchor.month, 1);
        final end = DateTime(_anchor.year, _anchor.month + 1, 0, 23, 59, 59);
        return (start, end);
      default:
        final start = DateTime(_anchor.year, 1, 1);
        final end = DateTime(_anchor.year, 12, 31, 23, 59, 59);
        return (start, end);
    }
  }

  String _periodLabel() {
    switch (_tab) {
      case 0:
        return DateFormat('d MMM yyyy').format(_anchor);
      case 1:
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}';
      case 2:
        return DateFormat('MMMM yyyy').format(_anchor);
      default:
        return DateFormat('yyyy').format(_anchor);
    }
  }

  Future<void> _downloadReport(double adherencePercent) async {
    final userName = context.read<AuthProvider>().profile?.fullName ?? 'Patient';
    try {
      await _reportService.generateAndSharePdf(
        userName: userName,
        adherencePercent: adherencePercent,
        periodLabel: _periodLabel(),
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Report generated');
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final range = _periodRange();

    return FutureBuilder<DoseStats>(
      future: _reportService.fetchDoseStats(userId, start: range.$1, end: range.$2),
      builder: (context, statsSnapshot) {
        final stats = statsSnapshot.data;
        final hasData = stats != null && !stats.isEmpty;
        final adherenceInt = stats == null || stats.total == 0
            ? 0
            : ((stats.taken / stats.total) * 100).round().clamp(0, 100);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Health Reports'),
            centerTitle: true,
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _pillTabs(),
              ),
              _periodNavigator(),
              Expanded(
                child: statsSnapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : hasData
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            children: _tab == 0
                                ? _dailyBody(adherenceInt, stats)
                                : _tab == 1
                                    ? _weeklyBody(adherenceInt, stats)
                                    : _tab == 2
                                        ? _monthlyBody(adherenceInt, stats)
                                        : _yearlyBody(adherenceInt, stats),
                          )
                        : const EmptyListPlaceholder(
                            icon: Icons.bar_chart_outlined,
                            title: 'No report data yet',
                            subtitle: 'Add medications and track doses to generate health reports.',
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pillTabs() {
    const labels = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: List.generate(4, (i) {
          final sel = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: sel ? Colors.white : AppColors.textGrey,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _periodNavigator() {
    String title;
    String hint;
    switch (_tab) {
      case 0:
        title = DateFormat('EEEE, d MMM yyyy').format(_anchor);
        hint = 'Tap arrows to browse days';
      case 1:
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        title = '${DateFormat('dd MMM').format(start)} – ${DateFormat('dd MMM yyyy').format(end)}';
        hint = 'Tap arrows to browse weeks';
      case 2:
        title = DateFormat('MMMM yyyy').format(_anchor);
        hint = 'Tap arrows to browse months';
      default:
        title = DateFormat('yyyy').format(_anchor);
        hint = 'Tap arrows to browse years';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _navCircle(Icons.chevron_left, () => _shift(-1)),
          Expanded(
            child: Column(
              children: [
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
              ],
            ),
          ),
          _navCircle(Icons.chevron_right, () => _shift(1)),
        ],
      ),
    );
  }

  void _shift(int dir) {
    setState(() {
      switch (_tab) {
        case 0:
          _anchor = _anchor.add(Duration(days: dir));
        case 1:
          _anchor = _anchor.add(Duration(days: dir * 7));
        case 2:
          _anchor = DateTime(_anchor.year, _anchor.month + dir, 1);
        default:
          _anchor = DateTime(_anchor.year + dir, _anchor.month, _anchor.day);
      }
    });
  }

  Widget _navCircle(IconData icon, VoidCallback onTap) {
    return Material(
      color: const Color(0xFFEEEEEE),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(10), child: Icon(icon, size: 22)),
      ),
    );
  }

  // ─────────────────── Daily ───────────────────
  List<Widget> _dailyBody(int adherencePercent, DoseStats stats) => [
        _adherenceCard(
          title: "Today's Adherence",
          percent: adherencePercent,
          taken: stats.taken,
          missed: stats.missed,
          pending: stats.pending,
          total: stats.total,
        ),
        const SizedBox(height: 20),
        if (stats.medStats.isNotEmpty) ...[
          const Text('Medication Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          for (final m in stats.medStats) _medStatusCard(m),
          const SizedBox(height: 12),
          _doseLegend(),
          const SizedBox(height: 20),
        ],
        _summaryCard(
          title: 'Daily Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          stats: stats,
          extraRows: [],
        ),
        const SizedBox(height: 16),
        _insightCard(
          "Today's Insight",
          stats.missed > 0
              ? 'You missed ${stats.missed} dose${stats.missed == 1 ? '' : 's'} today. Try setting a reminder or keeping your medication visible as a cue.'
              : stats.taken > 0
                  ? 'Great job! You took all your doses today. Keep up the consistency.'
                  : 'No doses recorded yet for today. Make sure to take your medications on time.',
        ),
      ];

  // ─────────────────── Weekly ───────────────────
  List<Widget> _weeklyBody(int adherencePercent, DoseStats stats) {
    // Use the real adherence score to drive both the ring badge and
    // the insight text, falling back to the period-level percent when
    // no 7-day data is available.
    final insight = _adherenceService.generateInsightText(adherencePercent.toDouble());
    return [
      _adherenceCard(
        title: "This Week's Adherence",
        percent: adherencePercent,
        taken: stats.taken,
        missed: stats.missed,
        pending: stats.pending,
        total: stats.total,
        insightText: insight,
      ),
      const SizedBox(height: 20),
      _summaryCard(
        title: 'Weekly Health Summary',
        adherencePercent: adherencePercent.toDouble(),
        stats: stats,
        extraRows: [],
      ),
      const SizedBox(height: 16),
      _insightCard('Weekly Insight', insight),
    ];
  }

  // ─────────────────── Monthly ───────────────────
  List<Widget> _monthlyBody(int adherencePercent, DoseStats stats) => [
        _adherenceCard(
          title: "This Month's Adherence",
          percent: adherencePercent,
          taken: stats.taken,
          missed: stats.missed,
          pending: stats.pending,
          total: stats.total,
        ),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Monthly Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          stats: stats,
          extraRows: [],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Monthly Insight',
          stats.missed > 0
              ? '${stats.missed} dose${stats.missed == 1 ? '' : 's'} were missed this month. Evening medications tend to be missed most — consider a reminder after dinner.'
              : stats.taken > 0
                  ? 'Your adherence remained strong throughout the month. Keep maintaining this habit!'
                  : 'No doses recorded this month. Add medications and log doses to track monthly progress.',
        ),
      ];

  // ─────────────────── Yearly ───────────────────
  List<Widget> _yearlyBody(int adherencePercent, DoseStats stats) => [
        _adherenceCard(
          title: "This Year's Adherence",
          percent: adherencePercent,
          taken: stats.taken,
          missed: stats.missed,
          pending: stats.pending,
          total: stats.total,
        ),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Annual Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          stats: stats,
          extraRows: [],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Annual Insight',
          stats.total > 0
              ? 'You tracked ${stats.total} dose${stats.total == 1 ? '' : 's'} this year with an overall adherence of $adherencePercent%. Adaptive reminders can help reduce missed doses further.'
              : 'No doses recorded this year yet. Start tracking your medications to see annual insights.',
        ),
      ];

  // ─────────────────── Widgets ───────────────────

  Widget _adherenceCard({
    required String title,
    required int percent,
    required int taken,
    required int missed,
    required int pending,
    required int total,
    /// Optional insight text shown directly below the ring. When provided
    /// (weekly tab), the AI-generated text appears at a glance without the
    /// user having to scroll to the insight card.
    String? insightText,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 32,
                        sectionsSpace: 0,
                        sections: [
                          PieChartSectionData(
                            value: percent.toDouble(),
                            radius: 12,
                            showTitle: false,
                            color: AppColors.navy,
                          ),
                          PieChartSectionData(
                            value: (100 - percent).toDouble(),
                            radius: 12,
                            showTitle: false,
                            color: const Color(0xFFE8E8E8),
                          ),
                        ],
                      ),
                    ),
                    Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: AppColors.navy)),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          percent >= 80 ? Icons.trending_up : Icons.trending_down,
                          color: percent >= 80 ? AppColors.successGreen : AppColors.warningAmber,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          percent >= 80 ? 'On Track' : 'Needs Attention',
                          style: TextStyle(
                            color: percent >= 80 ? AppColors.successGreen : AppColors.warningAmber,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _statLine('Taken', '$taken'),
                    _statLine('Missed', '$missed'),
                    _statLine('Pending', '$pending'),
                    _statLine('Total doses', '$total', bold: true),
                  ],
                ),
              ),
            ],
          ),
          // Insight text shown below the ring when available (weekly tab).
          if (insightText != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insightText,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  /// Builds a medication status card from real [MedStat] data.
  Widget _medStatusCard(MedStat m) {
    final pct = m.adherencePct;
    final Color pctColor = pct >= 80
        ? AppColors.primaryTeal
        : pct >= 50
            ? AppColors.warningAmber
            : AppColors.errorRed;

    // Build a list of bool? representing taken/missed/pending doses
    final doses = <bool?>[
      ...List.filled(m.taken, true),
      ...List.filled(m.missed, false),
      ...List.filled(m.pending, null),
    ];
    // Cap display at 6 dots so the card doesn't overflow
    final displayDoses = doses.take(6).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, color: pctColor)),
              ],
            ),
            Text('${m.total} dose${m.total == 1 ? '' : 's'}', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
            const SizedBox(height: 10),
            Row(
              children: displayDoses.map((d) {
                if (d == true) {
                  return const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: AppColors.primaryTeal, size: 22));
                }
                if (d == false) {
                  return const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cancel, color: AppColors.errorRed, size: 22));
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(Icons.circle_outlined, color: AppColors.navy.withValues(alpha: 0.4), size: 22),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _doseLegend() {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle, color: AppColors.primaryTeal, size: 16),
        SizedBox(width: 4),
        Text('Taken', style: TextStyle(fontSize: 11)),
        SizedBox(width: 12),
        Icon(Icons.cancel, color: AppColors.errorRed, size: 16),
        SizedBox(width: 4),
        Text('Missed', style: TextStyle(fontSize: 11)),
        SizedBox(width: 12),
        Icon(Icons.circle_outlined, color: AppColors.navy, size: 16),
        SizedBox(width: 4),
        Text('Pending', style: TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required double adherencePercent,
    required DoseStats stats,
    required List<_SummaryRow> extraRows,
  }) {
    final activeMeds = stats.medStats.length;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          _summaryRow('Active medications', '$activeMeds'),
          _summaryRow('Total doses', '${stats.total}'),
          _summaryRow('Doses taken', '${stats.taken}',
              icon: Icons.check_circle, iconColor: AppColors.primaryTeal),
          _summaryRow('Doses missed', '${stats.missed}',
              icon: Icons.cancel, iconColor: AppColors.errorRed),
          if (stats.pending > 0)
            _summaryRow('Doses pending', '${stats.pending}',
                icon: Icons.circle_outlined, iconColor: AppColors.navy),
          for (final r in extraRows)
            _summaryRow(r.label, r.value),
          const SizedBox(height: 12),
          GradientPrimaryButton(
            label: 'Download Full Report',
            onPressed: () => _downloadReport(adherencePercent),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (icon != null) ...[
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(width: 4),
          ],
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _insightCard(String title, String body) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4FC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: Colors.blue.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.blueGrey.shade800, height: 1.45, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryRow {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);
}
