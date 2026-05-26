import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/greeting_helper.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, UserDataProvider>(
      builder: (context, auth, data, _) {
        final profile = auth.profile;
        final firstName = profile?.firstName ?? 'there';
        final isDependent = profile?.isDependent ?? false;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GreetingHelper.dashboardTitle(firstName),
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
                  if (!data.hasMedications && !data.hasReminders)
                    _emptyOverview()
                  else
                    _overviewCard(data),
                  const SizedBox(height: 14),
                  if (data.hasReminders)
                    _nextReminderCard()
                  else
                    _emptyNextReminder(),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Upcoming Appointments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (data.hasAppointments)
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.appointments),
                          child: const Text('See All', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (data.hasAppointments)
                    _appointmentCard()
                  else
                    const EmptyListPlaceholder(
                      icon: Icons.calendar_month_outlined,
                      title: 'No upcoming appointments',
                      subtitle: 'Add an appointment to see it here.',
                    ),
                  const SizedBox(height: 24),
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
                  if (data.hasAlerts)
                    ...data.alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _alertRow(
                            AppColors.errorRed,
                            a['title'] ?? '',
                            a['time'] ?? '',
                          ),
                        ))
                  else
                    const EmptyListPlaceholder(
                      icon: Icons.notifications_none_outlined,
                      title: 'No alerts yet',
                      subtitle: 'Warnings and reminders will appear here.',
                    ),
                ],
              ],
            ),
          ),
        );
      },
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
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's Overview", style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
          SizedBox(height: 8),
          Text('No doses scheduled yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Add medications to track adherence', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptyNextReminder() {
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

  Widget _overviewCard(UserDataProvider data) {
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
                Text('0 of 0 doses taken', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('0 medications active', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
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
                    sections: [
                      PieChartSectionData(value: 1, radius: 14, showTitle: false, color: const Color(0xFFE6E6E6)),
                    ],
                  ),
                ),
                const Text('0%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nextReminderCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryTeal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Next Reminder', style: TextStyle(color: Colors.white70, fontSize: 13)),
                SizedBox(height: 6),
                Text('—', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(Icons.medication_liquid_rounded, color: Colors.white, size: 28),
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

  Widget _appointmentCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const ListTile(
        title: Text('Appointment', style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Details from your list'),
      ),
    );
  }

  Widget _alertRow(Color accent, String title, String time) {
    return Container(
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
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text(time, style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
