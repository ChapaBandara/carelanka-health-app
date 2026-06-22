import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/core/utils/greeting_helper.dart';
import 'package:carelanka_app/core/utils/medication_schedule_helper.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/alert_service.dart';
import 'package:carelanka_app/services/appointment_service.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _checkupOverdue = false;
  int _daysSinceVisit = 0;

  @override
  void initState() {
    super.initState();
    // Run background checks and load checkup state after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final uid = context.activeUid;
      if (uid.isEmpty) return;

      // Fire-and-forget background tasks.
      ReminderService().runAdaptiveLogic(uid).catchError((_) {});
      AdherenceService().checkAllMedicationsStock(uid).catchError((_) {});

      // Check for missed doses and auto-log them.
      await ReminderService().checkMissedReminders(uid);
      await _rescheduleAllNotifications(uid);

      _checkAndSendPeriodReport(uid);

      // Load checkup banner state — silently, never surfacing errors.
      try {
        final service = CheckupService();
        final overdue = await service.isCheckupOverdue(uid);
        final days = await service.getDaysSinceLastVisit(uid);
        if (mounted) {
          setState(() {
            _checkupOverdue = overdue;
            _daysSinceVisit = days;
          });
        }
      } catch (_) {}
    });
  }

  Future<void> _checkAndSendPeriodReport(String userId) async {
    try {
      final now = DateTime.now();
      if (now.hour < 21) return;

      final prefs = await SharedPreferences.getInstance();
      final lastKey = 'last_report_notif_$userId';
      final lastSent = prefs.getInt(lastKey) ?? 0;
      final lastDate = DateTime.fromMillisecondsSinceEpoch(lastSent);
      if (lastDate.year == now.year &&
          lastDate.month == now.month &&
          lastDate.day == now.day) {
        return;
      }

      String period = 'Daily';
      DateTime start = DateTime(now.year, now.month, now.day);

      if (now.weekday == DateTime.sunday) {
        period = 'Weekly';
        start = now.subtract(const Duration(days: 6));
      }
      if (now.day == _lastDayOfMonth(now)) {
        period = 'Monthly';
        start = DateTime(now.year, now.month, 1);
      }
      if (now.month == 12 && now.day == 31) {
        period = 'Yearly';
        start = DateTime(now.year, 1, 1);
      }

      final score = await ReminderService()
          .calculateAdherencePercent(userId, start: start, end: now);

      await NotificationService.instance
          .showAdherenceReportNotification(
        adherenceScore: score,
        period: period,
      );

      await prefs.setInt(lastKey, now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  int _lastDayOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0).day;

  Future<void> _rescheduleAllNotifications(String userId) async {
    try {
      final medSnap = await FirebaseFirestore.instance
          .collection('medications')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      for (final doc in medSnap.docs) {
        final data = doc.data();
        final times =
            List<String>.from(data['scheduledTimes'] as List? ?? []);
        final name = data['name'] as String? ?? '';
        if (times.isNotEmpty) {
          await NotificationService.instance.scheduleMedicationReminders(
            medicationId: doc.id,
            title: '$name — tap to take your dose',
            timeStrings: times,
          );
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, familyProvider, _) {
        final userId = context.activeUid;
        return Consumer2<AuthProvider, UserDataProvider>(
      builder: (context, auth, data, _) {
        final profile = auth.profile;
        final displayName = familyProvider.isViewingFamilyMember
            ? familyProvider.activeDisplayName.split(' ').first
            : (auth.profile?.firstName ?? 'there');
        final isDependent = profile?.isDependent ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Consumer<FamilyProvider>(
                  builder: (context, family, _) {
                    if (!family.isViewingFamilyMember) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTeal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.swap_horiz, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Viewing ${family.activeDisplayName}\'s account',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              context.read<FamilyProvider>().switchToSelf();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                AppRoutes.dashboard,
                                (_) => false,
                              );
                            },
                            child: const Text(
                              'Switch Back',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GreetingHelper.dashboardTitle(displayName),
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isDependent
                                ? 'Your profile is linked to a family account'
                                : 'Here is your health snapshot',
                            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.reminderHistory),
                      icon: const Icon(Icons.notifications_outlined, size: 28),
                    ),
                  ],
                ),
                if (isDependent) ...[
                  const SizedBox(height: 20),
                  _dependentBanner(profile?.guardianName),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.family_restroom, color: AppColors.primaryTeal),
                      title: const Text('Family connection', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('Managed by ${profile?.guardianName ?? 'your guardian'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(context, AppRoutes.family),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 20),
                  if (_checkupOverdue) ...[_checkupBanner(context), const SizedBox(height: 14)],
                  _medicationOverviewSection(context),
                  const SizedBox(height: 22),
                  const Text('Quick actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _quickTile(context, Icons.medication_rounded, 'My Medications', AppColors.primaryTeal, AppRoutes.medicationList)),
                      const SizedBox(width: 10),
                      Expanded(child: _quickTile(context, Icons.folder_open, 'Records', const Color(0xFF83C5BE), AppRoutes.healthRecords)),
                      const SizedBox(width: 10),
                      Expanded(child: _quickTile(context, Icons.calendar_month_rounded, 'Appointments', AppColors.warningAmber, AppRoutes.appointments)),
                      const SizedBox(width: 10),
                      Expanded(child: _quickTile(context, Icons.bar_chart_rounded, 'Reports', AppColors.purpleAccent, AppRoutes.reports)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _upcomingAppointmentsSection(context),
                  const SizedBox(height: 24),
                  _recentAlertsSection(context),
                ],
              ],
            ),
          ),
        );
      },
    );
      },
    );
  }

  Widget _checkupBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.health_and_safety_outlined, color: Color(0xFFF9A825), size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Checkup Overdue',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF5D4037)),
                ),
                const SizedBox(height: 2),
                Text(
                  "You haven't had a checkup in $_daysSinceVisit day${_daysSinceVisit == 1 ? '' : 's'}.",
                  style: const TextStyle(color: Color(0xFF795548), fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              backgroundColor: const Color(0xFFFDD835),
              foregroundColor: const Color(0xFF5D4037),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pushNamed(context, AppRoutes.appointments),
            child: const Text('Schedule Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _dependentBanner(String? guardian) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoBannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB8D4E8)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.navy),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'As a dependent profile, you can view your link to ${guardian ?? 'your family account'}. Health data is managed by the primary account holder.',
              style: TextStyle(color: Colors.blueGrey.shade800, height: 1.4, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicationOverviewSection(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeUid;
    if (userId.isEmpty) {
      return Column(
        children: [
          _emptyOverview(),
          const SizedBox(height: 14),
          _noReminderCard(),
        ],
      );
    }

    return StreamBuilder<List<Map<String, String>>>(
      stream: IllnessService().watchIllnessMaps(userId),
      builder: (context, illnessSnap) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: MedicationService().watchMedications(userId),
          builder: (context, medSnap) {
            return StreamBuilder<int>(
              stream: ReminderService().watchTakenDosesToday(userId),
              builder: (context, takenSnap) {
                if (illnessSnap.connectionState == ConnectionState.waiting ||
                    medSnap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final activeIllnessIds = (illnessSnap.data ?? [])
                    .where((i) => i['status'] != 'completed')
                    .map((i) => i['illnessId'] ?? '')
                    .where((id) => id.isNotEmpty)
                    .toSet();
                final activeMeds = MedicationService()
                    .filterActiveForIllnesses(medSnap.data ?? [], activeIllnessIds);

                final now = DateTime.now();
                final totalDoses = MedicationScheduleHelper.totalDosesToday(activeMeds, now);
                final taken = takenSnap.data ?? 0;
                final hasMeds = activeMeds.isNotEmpty;

                return FutureBuilder<AdherenceResult>(
                  future: AdherenceService().calculateOverallScore(userId),
                  builder: (context, adherenceSnap) {
                    final adherence = adherenceSnap.data;
                    return Column(
                      children: [
                        if (!hasMeds)
                          _emptyOverview()
                        else
                          _overviewCard(
                            takenDoses: taken,
                            totalDoses: totalDoses,
                            activeMedicationCount: activeMeds.length,
                            adherence: adherence,
                          ),
                        const SizedBox(height: 14),
                        FutureBuilder<Map<String, dynamic>?>(
                          future: _getNextReminder(userId),
                          builder: (context, snapshot) {
                            final next = snapshot.data;
                            if (next == null) {
                              return _noReminderCard();
                            }
                            return _nextReminderCard(
                              medicationName: next['name'] as String,
                              time: next['time'] as String,
                              condition: next['condition'] as String,
                            );
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
      },
    );
  }

  Widget _emptyOverview() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Today's Overview", style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                SizedBox(height: 6),
                Text('No doses scheduled yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Add medications to track adherence', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
              ],
            ),
          ),
          // Placeholder circle — same size as the PieChart in _overviewCard
          SizedBox(
            width: 100,
            height: 100,
            child: Center(
              child: Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6E6E6),
                ),
                alignment: Alignment.center,
                child: const Text('—', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textGrey)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _getNextReminder(String userId) async {
    try {
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance
          .collection('medications')
          .where('userId', isEqualTo: userId)
          .where('active', isEqualTo: true)
          .get();

      final upcoming = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final times = List<String>.from(
            data['scheduledTimes'] as List? ?? []);
        final name = data['name'] as String? ?? '';
        final condition = data['condition'] as String? ?? '';

        for (final timeStr in times) {
          final parts = timeStr.split(':');
          if (parts.length < 2) continue;
          var hour = int.tryParse(parts[0]) ?? 0;
          final minPart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
          final minute = int.tryParse(minPart) ?? 0;
          if (timeStr.toLowerCase().contains('pm') && hour < 12) {
            hour += 12;
          }
          final scheduled = DateTime(
              now.year, now.month, now.day, hour, minute);
          if (scheduled.isAfter(now)) {
            upcoming.add({
              'name': name,
              'condition': condition,
              'time': timeStr,
              'scheduledAt': scheduled,
            });
          }
        }
      }

      if (upcoming.isEmpty) return null;
      upcoming.sort((a, b) =>
          (a['scheduledAt'] as DateTime)
              .compareTo(b['scheduledAt'] as DateTime));
      return upcoming.first;
    } catch (_) {
      return null;
    }
  }

  Widget _noReminderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Reminder', style: TextStyle(fontSize: 13, color: AppColors.textGrey)),
                SizedBox(height: 6),
                Text('None scheduled', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              ],
            ),
          ),
          Icon(Icons.medication_liquid_outlined, color: AppColors.textGrey, size: 32),
        ],
      ),
    );
  }

  Widget _overviewCard({
    required int takenDoses,
    required int totalDoses,
    required int activeMedicationCount,
    AdherenceResult? adherence,
  }) {
    // Today's dose progress drives the pie chart fill.
    final todayPercent = totalDoses == 0 ? 0 : ((takenDoses / totalDoses) * 100).round();
    final remaining = (totalDoses - takenDoses).clamp(0, totalDoses).toDouble();
    final takenValue = takenDoses.toDouble();
    final chartSections = totalDoses == 0
        ? [
            PieChartSectionData(value: 1, radius: 14, showTitle: false, color: const Color(0xFFE6E6E6)),
          ]
        : [
            if (takenValue > 0)
              PieChartSectionData(value: takenValue, radius: 14, showTitle: false, color: AppColors.primaryTeal),
            if (remaining > 0)
              PieChartSectionData(value: remaining, radius: 14, showTitle: false, color: const Color(0xFFE6E6E6)),
          ];

    // 7-day adherence label — shown when data is available.
    final adherenceLabel = adherence != null && adherence.total > 0
        ? '${adherence.confirmed} of ${adherence.total} confirmed (7d)'
        : '$activeMedicationCount active medication${activeMedicationCount == 1 ? '' : 's'}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Today's Overview", style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  '$takenDoses of $totalDoses doses taken',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  adherenceLabel,
                  style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                ),
                if (adherence != null && adherence.total > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '7-day adherence: ${adherence.scoreInt}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: adherence.scoreInt >= 80
                          ? AppColors.successGreen
                          : adherence.scoreInt >= 50
                              ? AppColors.warningAmber
                              : AppColors.errorRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 32,
                    sections: chartSections,
                  ),
                ),
                Text('$todayPercent%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextReminderCard({
    required String medicationName,
    required String time,
    required String condition,
  }) {
    final medicationLabel = [
      medicationName,
      if (condition.isNotEmpty) condition,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Next Reminder', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 6),
                Text(
                  time,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                ),
                if (medicationLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    medicationLabel,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 28),
        ],
      ),
    );
  }

  Widget _quickTile(BuildContext context, IconData icon, String label, Color iconColor, String route) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pushNamed(context, route),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textDark, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _upcomingAppointmentsSection(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeUid;
    if (userId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<Map<String, String>>>(
      stream: AppointmentService().watchAppointmentMaps(userId),
      builder: (context, snapshot) {
        final upcoming = (snapshot.data ?? []).where((a) => a['period'] != 'past').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upcoming Appointments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (upcoming.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.appointments),
                    child: const Text('See All', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              const EmptyListPlaceholder(
                icon: Icons.calendar_month_outlined,
                title: 'No upcoming appointments',
                subtitle: 'Add an appointment to see it here.',
              )
            else
              _appointmentCard(upcoming.first),
          ],
        );
      },
    );
      },
    );
  }

  Color _badgeColor(String badge) {
    if (badge.contains('TODAY')) return AppColors.errorRed;
    if (badge.contains('TOMORROW')) return const Color(0xFFF9A825);
    return const Color(0xFF64B5F6);
  }

  Widget _appointmentCard(Map<String, String> appointment) {
    final badge = appointment['badge'] ?? '';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 56,
              decoration: const BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    appointment['day'] ?? '—',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  Text(
                    appointment['month'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    appointment['year'] ?? '',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          appointment['doctor'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy),
                        ),
                      ),
                      if (badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _badgeColor(badge), borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            badge,
                            style: TextStyle(
                              color: badge.contains('IN ') ? AppColors.navy : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.place_outlined, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          appointment['hospital'] ?? '',
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(
                        appointment['time'] ?? '',
                        style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _recentAlertsSection(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeUid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.alerts),
              child: const Text('See All', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (userId.isEmpty)
          const EmptyListPlaceholder(
            icon: Icons.notifications_none_outlined,
            title: 'No alerts yet',
            subtitle: 'Warnings and reminders will appear here.',
          )
        else
          StreamBuilder<List<Map<String, String>>>(
            stream: AlertService().watchAlertMaps(userId),
            builder: (context, snapshot) {
              final alerts = (snapshot.data ?? []).take(3).toList();
              if (alerts.isEmpty) {
                return const EmptyListPlaceholder(
                  icon: Icons.notifications_none_outlined,
                  title: 'No alerts yet',
                  subtitle: 'Warnings and reminders will appear here.',
                );
              }
              return Column(
                children: [
                  for (final a in alerts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _alertRow(context, a),
                    ),
                ],
              );
            },
          ),
      ],
    );
      },
    );
  }

  Color _alertAccent(String key) {
    switch (key) {
      case 'red':
        return AppColors.errorRed;
      case 'orange':
        return const Color(0xFFFF9800);
      case 'purple':
        return AppColors.purpleAccent;
      default:
        return AppColors.primaryTeal;
    }
  }

  void _openAlert(BuildContext context, Map<String, String> alert) {
    final type = alert['type'] ?? '';
    if (type == 'drug' || type == 'allergy') {
      Navigator.pushNamed(context, '/drug-conflict-detail', arguments: alert);
      return;
    }
    if (type == 'checkup') {
      Navigator.pushNamed(context, AppRoutes.appointments);
      return;
    }
    if (type == 'missed') {
      Navigator.pushNamed(context, AppRoutes.reminderHistory);
      return;
    }
    Navigator.pushNamed(context, AppRoutes.alerts);
  }

  Widget _alertRow(BuildContext context, Map<String, String> alert) {
    final accent = _alertAccent(alert['accent'] ?? 'teal');
    return InkWell(
      onTap: () => _openAlert(context, alert),
      borderRadius: BorderRadius.circular(12),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 4, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(alert['time'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
