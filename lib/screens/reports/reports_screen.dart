import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
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

    return StreamBuilder<List<Map<String, String>>>(
      stream: ReminderService().watchReminderMaps(userId),
      builder: (context, logSnapshot) {
        final hasData = (logSnapshot.data ?? []).isNotEmpty;

        return FutureBuilder<double>(
          future: _reportService.adherencePercent(userId, start: range.$1, end: range.$2),
          builder: (context, adherenceSnapshot) {
            final adherence = adherenceSnapshot.data ?? 0;
            final adherenceInt = adherence.round().clamp(0, 100);

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
            child: hasData
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: _tab == 0
                        ? _dailyBody(adherenceInt)
                        : _tab == 1
                            ? _weeklyBody(adherenceInt)
                            : _tab == 2
                                ? _monthlyBody(adherenceInt)
                                : _yearlyBody(adherenceInt),
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

  List<Widget> _dailyBody(int adherencePercent) => [
        _adherenceCard(
          title: "Today's Adherence",
          percent: adherencePercent,
          trend: 'Improving',
          trendUp: true,
          taken: 3,
          missed: 1,
          pending: 2,
          total: 6,
        ),
        const SizedBox(height: 20),
        const Text('Medication Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        _medStatusCard('Aspirin', 'Hypertension • 2 doses', '100%', const [true, true], null),
        const SizedBox(height: 10),
        _medStatusCard('Metformin', 'Diabetes • 3 doses', '33%', const [true, false, null], AppColors.errorRed),
        const SizedBox(height: 10),
        _medStatusCard('Losartan', 'Hypertension • 2 doses', '50%', [true, null], AppColors.warningAmber),
        const SizedBox(height: 12),
        _doseLegend(),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Daily Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          rows: const [
            _SummaryRow('Active medications', '3'),
            _SummaryRow('Total doses scheduled', '6'),
            _SummaryRow('Doses taken', '3', icon: Icons.check_circle, iconColor: AppColors.primaryTeal),
            _SummaryRow('Doses missed', '1', icon: Icons.cancel, iconColor: AppColors.errorRed),
            _SummaryRow('Doses pending', '2', icon: Icons.circle_outlined, iconColor: AppColors.navy),
            _SummaryRow('Adherence trend', 'Improving', trend: true),
          ],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Today\'s Insight',
          'Good progress! You missed your morning Metformin dose. Try taking it immediately after breakfast. CareLanka will continue adjusting reminder timing based on your response patterns.',
        ),
      ];

  List<Widget> _weeklyBody(int adherencePercent) => [
        _adherenceCard(
          title: "This Week's Adherence",
          percent: adherencePercent,
          trend: '+5% vs last week',
          trendUp: true,
          taken: 18,
          missed: 3,
          pending: 0,
          total: 21,
        ),
        const SizedBox(height: 20),
        const Text('Daily Performance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _dayPerf('Mon', 100, AppColors.successGreen),
              _dayPerf('Tue', 80, AppColors.warningAmber),
              _dayPerf('Wed', 100, AppColors.successGreen),
              _dayPerf('Thu', 67, AppColors.errorRed),
              _dayPerf('Fri', 100, AppColors.successGreen),
              _dayPerf('Sat', 90, AppColors.primaryTeal),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Weekly Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          rows: const [
            _SummaryRow('Active medications', '3'),
            _SummaryRow('Total doses scheduled', '21'),
            _SummaryRow('Doses taken', '18', icon: Icons.check_circle, iconColor: AppColors.primaryTeal),
            _SummaryRow('Doses missed', '3', icon: Icons.cancel, iconColor: AppColors.errorRed),
            _SummaryRow('Weekly trend', 'Improved by 5%', trend: true),
          ],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Weekly Insight',
          'Your adherence improved compared with last week. Most missed doses occurred in the evening. Consider taking your medication immediately after dinner.',
        ),
      ];

  List<Widget> _monthlyBody(int adherencePercent) => [
        _adherenceCard(
          title: "This Month's Adherence",
          percent: adherencePercent,
          trend: '+3% vs last month',
          trendUp: true,
          taken: 106,
          missed: 14,
          pending: 0,
          total: 120,
        ),
        const SizedBox(height: 20),
        const Text('Weekly Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _weekBox('Week 1', 92, AppColors.primaryTeal)),
            const SizedBox(width: 8),
            Expanded(child: _weekBox('Week 2', 86, AppColors.warningAmber)),
            const SizedBox(width: 8),
            Expanded(child: _weekBox('Week 3', 90, AppColors.primaryTeal)),
            const SizedBox(width: 8),
            Expanded(child: _weekBox('Week 4', 84, AppColors.warningAmber)),
          ],
        ),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Monthly Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          rows: const [
            _SummaryRow('Active medications', '3'),
            _SummaryRow('Total doses scheduled', '120'),
            _SummaryRow('Doses taken', '106', icon: Icons.check_circle, iconColor: AppColors.primaryTeal),
            _SummaryRow('Doses missed', '14', icon: Icons.cancel, iconColor: AppColors.errorRed),
            _SummaryRow('Monthly trend', 'Improved by 3%', trend: true),
          ],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Monthly Insight',
          'Your adherence remained strong throughout the month. Evening medications were missed most frequently, suggesting reminder timing may need adjustment.',
        ),
      ];

  List<Widget> _yearlyBody(int adherencePercent) => [
        _adherenceCard(
          title: "This Year's Adherence",
          percent: adherencePercent,
          trend: '+8% vs start of year',
          trendUp: true,
          taken: 1287,
          missed: 159,
          pending: 0,
          total: 1446,
        ),
        const SizedBox(height: 20),
        const Text('Monthly Breakdown', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: [
            _monthBox('JAN', 91, AppColors.primaryTeal),
            _monthBox('FEB', 88, AppColors.warningAmber),
            _monthBox('MAR', 94, AppColors.primaryTeal),
            _monthBox('APR', 85, AppColors.warningAmber),
            _monthBox('MAY', 88, AppColors.warningAmber),
            _monthBox('JUN', 90, AppColors.primaryTeal),
            _monthBox('JUL', 87, AppColors.warningAmber),
            _monthBox('AUG', 89, AppColors.warningAmber),
            _monthBox('SEP', 91, AppColors.primaryTeal),
            _monthBox('OCT', 88, AppColors.warningAmber),
            _monthBox('NOV', 90, AppColors.primaryTeal),
            _monthBox('DEC', 87, AppColors.warningAmber),
          ],
        ),
        const SizedBox(height: 20),
        _summaryCard(
          title: 'Annual Health Summary',
          adherencePercent: adherencePercent.toDouble(),
          rows: const [
            _SummaryRow('Active medications', '3'),
            _SummaryRow('Total doses scheduled', '1,446'),
            _SummaryRow('Doses taken', '1,287', icon: Icons.check_circle, iconColor: AppColors.primaryTeal),
            _SummaryRow('Doses missed', '159', icon: Icons.cancel, iconColor: AppColors.errorRed),
            _SummaryRow('Longest adherence streak', '47 days'),
            _SummaryRow('Annual trend', 'Improved by 8%', trend: true),
          ],
        ),
        const SizedBox(height: 16),
        _insightCard(
          'Annual Insight',
          'Your medication adherence improved significantly over the year. Adaptive reminders helped reduce missed doses and improved consistency.',
        ),
      ];

  Widget _adherenceCard({
    required String title,
    required int percent,
    required String trend,
    required bool trendUp,
    required int taken,
    required int missed,
    required int pending,
    required int total,
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
                        Icon(trendUp ? Icons.trending_up : Icons.trending_down, color: AppColors.successGreen, size: 20),
                        const SizedBox(width: 6),
                        Text(trend, style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.w600, fontSize: 13)),
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

  Widget _medStatusCard(String name, String sub, String pct, List<bool?> doses, Color? pctColor) {
    return Container(
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
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(pct, style: TextStyle(fontWeight: FontWeight.w800, color: pctColor ?? AppColors.primaryTeal)),
            ],
          ),
          Text(sub, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: doses.map((d) {
              if (d == true) return const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.check_circle, color: AppColors.primaryTeal, size: 22));
              if (d == false) return const Padding(padding: EdgeInsets.only(right: 8), child: Icon(Icons.cancel, color: AppColors.errorRed, size: 22));
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.circle_outlined, color: AppColors.navy.withValues(alpha: 0.4), size: 22),
              );
            }).toList(),
          ),
        ],
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
    required List<_SummaryRow> rows,
    required double adherencePercent,
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
          const SizedBox(height: 12),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(r.label, style: const TextStyle(fontSize: 14))),
                    if (r.trend)
                      Row(
                        children: [
                          const Icon(Icons.trending_up, color: AppColors.successGreen, size: 18),
                          const SizedBox(width: 4),
                          Text(r.value, style: const TextStyle(color: AppColors.successGreen, fontWeight: FontWeight.w600)),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (r.icon != null) ...[
                            Icon(r.icon, size: 18, color: r.iconColor),
                            const SizedBox(width: 4),
                          ],
                          Text(r.value, style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ),
              )),
          const SizedBox(height: 12),
          GradientPrimaryButton(
            label: 'Download Full Report',
            onPressed: () => _downloadReport(adherencePercent),
          ),
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

  Widget _dayPerf(String day, int pct, Color color) {
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        children: [
          Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(height: 6),
          Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _weekBox(String label, int pct, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  Widget _monthBox(String mon, int pct, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(mon, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          Text('$pct%', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ],
      ),
    );
  }
}

class _SummaryRow {
  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final bool trend;
  const _SummaryRow(this.label, this.value, {this.icon, this.iconColor, this.trend = false});
}
