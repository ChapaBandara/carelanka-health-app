import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/appointment_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tab.indexIsChanging) return;
    final showFab = _tab.index == 0;
    if (showFab != _showFab) setState(() => _showFab = showFab);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTabChanged);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeScopeId;

    return StreamBuilder<List<Map<String, String>>>(
      stream: AppointmentService().watchAppointmentMaps(userId),
      builder: (context, snapshot) {
        final appointments = snapshot.data ?? [];
        final upcoming = appointments
            .where((a) => a['period'] != 'past' && a['status'] != 'completed')
            .toList();
        final past = appointments
            .where((a) => a['period'] == 'past' || a['status'] == 'completed')
            .toList();

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
          floatingActionButton: _showFab
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 4),
                  child: GradientWideFab(
                    label: 'Add Appointment',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.addAppointment),
                  ),
                )
              : null,
          body: TabBarView(
            controller: _tab,
            children: [
              _appointmentList(
                context,
                upcoming,
                isPast: false,
                emptyTitle: 'No upcoming appointments',
                emptySubtitle: 'Tap Add Appointment to schedule your first visit.',
              ),
              _appointmentList(
                context,
                past,
                isPast: true,
                emptyTitle: 'No past appointments',
                emptySubtitle: 'Completed visits will appear here.',
              ),
            ],
          ),
        );
      },
    );
      },
    );
  }

  Widget _appointmentList(
    BuildContext context,
    List<Map<String, String>> list, {
    required bool isPast,
    required String emptyTitle,
    String? emptySubtitle,
  }) {
    if (list.isEmpty) {
      return EmptyListPlaceholder(
        icon: Icons.calendar_month_outlined,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, isPast ? 24 : 100),
      children: [
        for (final a in list) ...[
          _apptCard(context, a, isPast: isPast),
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

  Widget _apptCard(BuildContext context, Map<String, String> appointment, {required bool isPast}) {
    final appointmentId = appointment['appointmentId'] ?? '';
    final doctor = appointment['doctor'] ?? '';
    final badge = isPast ? '' : (appointment['badge'] ?? '');

    final cardColor = isPast ? const Color(0xFFF0F0F0) : Colors.white;
    final dateStripColor = isPast ? const Color(0xFFB0B0B0) : AppColors.primaryTeal;
    final titleColor = isPast ? const Color(0xFF757575) : AppColors.navy;
    final metaColor = isPast ? const Color(0xFF9E9E9E) : AppColors.textGrey;

    return Dismissible(
      key: ValueKey(appointmentId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.errorRed,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      confirmDismiss: (_) => _confirmDelete(context, doctor),
      onDismissed: (_) => _deleteAppointment(appointmentId),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: isPast
              ? null
              : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
                ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56,
                decoration: BoxDecoration(
                  color: dateStripColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      appointment['day'] ?? '—',
                      style: TextStyle(color: Colors.white.withValues(alpha: isPast ? 0.95 : 1), fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    Text(
                      appointment['month'] ?? '',
                      style: TextStyle(color: Colors.white.withValues(alpha: isPast ? 0.9 : 1), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      appointment['year'] ?? '',
                      style: TextStyle(color: Colors.white.withValues(alpha: isPast ? 0.85 : 0.9), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(doctor, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: titleColor)),
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
                                Icon(Icons.place_outlined, size: 16, color: metaColor),
                                const SizedBox(width: 4),
                                Expanded(child: Text(appointment['hospital'] ?? '', style: TextStyle(color: metaColor, fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: metaColor),
                                const SizedBox(width: 4),
                                Text(appointment['time'] ?? '', style: TextStyle(color: metaColor, fontSize: 13)),
                              ],
                            ),
                            if ((appointment['note'] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                appointment['note']!,
                                style: TextStyle(color: metaColor, fontSize: 13, fontStyle: FontStyle.italic),
                              ),
                            ],
                            // Met Doctor button — only shown on TODAY's appointments
                            if (!isPast && badge == 'TODAY') ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primaryTeal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () => _markMetDoctor(context, appointmentId, doctor),
                                  icon: const Icon(Icons.check_circle_outline, size: 18),
                                  label: const Text(
                                    'Met Doctor ✓',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: metaColor, size: 20),
                        padding: EdgeInsets.zero,
                        onSelected: (value) {
                          if (value == 'edit') {
                            Navigator.pushNamed(context, AppRoutes.addAppointment, arguments: appointment);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18, color: AppColors.navy),
                                SizedBox(width: 10),
                                Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
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
      ),
    );
  }

  Future<void> _markMetDoctor(BuildContext context, String appointmentId, String doctor) async {
    // Capture context-dependent objects before the first await.
    final messenger = ScaffoldMessenger.of(context);
    void showError(Object e) => showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm visit?'),
        content: Text('Mark your appointment with $doctor as completed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal),
            child: const Text('Met Doctor ✓', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AppointmentService().markAsCompleted(appointmentId);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('✅ Visit confirmed! Great job staying on top of your health.'),
          backgroundColor: AppColors.primaryTeal,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showError(e);
    }
  }

  Future<bool> _confirmDelete(BuildContext context, String doctor) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete appointment?'),
        content: Text('Delete appointment with $doctor? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    if (appointmentId.isEmpty) return;
    try {
      await AppointmentService().deleteAppointment(appointmentId);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }
}
