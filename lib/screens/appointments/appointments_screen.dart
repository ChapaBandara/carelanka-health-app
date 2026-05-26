import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/services/appointment_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: AppointmentService().watchAppointmentMaps(userId),
      builder: (context, snapshot) {
        final appointments = snapshot.data ?? [];
        final upcoming = appointments.where((a) => a['period'] != 'past').toList();
        final past = appointments.where((a) => a['period'] == 'past').toList();

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Appointments', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.navy,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      bottomNavigationBar: const CareLankaBottomNav(currentIndex: 0),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 4),
        child: GradientWideFab(
          label: 'Add Appointment',
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addAppointment),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: TabBarView(
        controller: _tab,
        children: [
          _appointmentList(upcoming, emptyTitle: 'No upcoming appointments', emptySubtitle: 'Tap Add Appointment to schedule your first visit.'),
          _appointmentList(past, emptyTitle: 'No past appointments', emptySubtitle: 'Completed visits will appear here.'),
        ],
      ),
    );
      },
    );
  }

  Widget _appointmentList(List<Map<String, String>> list, {required String emptyTitle, String? emptySubtitle}) {
    if (list.isEmpty) {
      return EmptyListPlaceholder(
        icon: Icons.calendar_month_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        for (final a in list) ...[
          _apptCard(
            a['day'] ?? '—',
            a['month'] ?? '',
            a['year'] ?? '',
            a['doctor'] ?? '',
            a['badge'] ?? '',
            _badgeColor(a['badge'] ?? ''),
            a['hospital'] ?? '',
            a['time'] ?? '',
            a['note'],
            (a['reminders'] ?? '').split('|').where((s) => s.isNotEmpty).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Color _badgeColor(String badge) {
    if (badge.contains('TODAY')) return AppColors.errorRed;
    if (badge.contains('TOMORROW')) return const Color(0xFFF9A825);
    return const Color(0xFF64B5F6);
  }

  Widget _apptCard(
    String day,
    String mon,
    String year,
    String doctor,
    String badge,
    Color badgeColor,
    String hospital,
    String time,
    String? note,
    List<String> reminders,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.primaryTeal,
              borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
            ),
            child: Column(
              children: [
                Text(day, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(mon, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                Text(year, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10)),
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
                        child: Text(doctor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                      ),
                      if (badge.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
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
                      Expanded(child: Text(hospital, style: const TextStyle(color: AppColors.textGrey, fontSize: 13))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(note, style: const TextStyle(color: AppColors.textGrey, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                  if (reminders.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      children: reminders
                          .map(
                            (t) => Chip(
                              label: Text(t, style: const TextStyle(color: AppColors.primaryTeal, fontSize: 11, fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFFE0F7F7),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              side: BorderSide.none,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
