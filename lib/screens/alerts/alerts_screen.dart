import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/alert_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 3, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeScopeId;

    return StreamBuilder<List<Map<String, String>>>(
      key: ValueKey(userId),
      stream: AlertService().watchAlertMaps(userId),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? [];

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Alerts and Warnings'),
        centerTitle: true,
        actions: [
          if (alerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                ),
                onPressed: () {},
                child: const Text('Mark all read', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tab,
          labelColor: AppColors.navy,
          unselectedLabelColor: AppColors.textGrey,
          indicatorColor: AppColors.primaryTeal,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Drug Conflicts'),
            Tab(text: 'Checkup'),
          ],
        ),
      ),
      bottomNavigationBar: const CareLankaBottomNav(currentIndex: 0),
      body: TabBarView(
        controller: _tab,
        children: [
          _list(alerts, filter: null),
          _list(alerts, filter: 'drug'),
          _list(alerts, filter: 'checkup'),
        ],
      ),
    );
      },
    );
      },
    );
  }

  Widget _list(List<Map<String, String>> alerts, {String? filter}) {
    final filtered = filter == null
        ? alerts
        : alerts.where((a) {
            final type = a['type'] ?? '';
            if (filter == 'drug') return type == 'drug' || type == 'allergy';
            return type == 'checkup';
          }).toList();

    if (filtered.isEmpty) {
      return EmptyListPlaceholder(
        icon: Icons.notifications_none_outlined,
        title: filter == null ? 'No alerts yet' : 'No alerts in this category',
        subtitle: 'Warnings and reminders will appear here when relevant.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(context, filtered[i]),
    );
  }

  Future<void> _markRead(BuildContext context, Map<String, String> a) async {
    final alertId = a['alertId'];
    if (alertId == null || alertId.isEmpty) return;
    try {
      await AlertService().markAsRead(alertId);
      if (context.mounted) {
        showFirebaseSuccessSnackBar(context, 'Alert marked as read');
      }
    } catch (e) {
      if (context.mounted) {
        showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      }
    }
  }

  Widget _card(BuildContext context, Map<String, String> a) {
    final accent = _color(a['accent'] ?? 'teal');
    final tint = _tint(a['tint'] ?? 'white');
    final isLowStockAlert = (a['type'] ?? '') == 'general' &&
            (a['title'] ?? '').toLowerCase().contains('low') ||
        (a['message'] ?? '').toLowerCase().contains('running low') ||
        (a['message'] ?? '').toLowerCase().contains('supply remaining');
    return InkWell(
      onTap: () {
        if (a['type'] == 'drug' || a['type'] == 'allergy') {
          Navigator.pushNamed(context, '/drug-conflict-detail', arguments: a);
        } else if (a['type'] == 'checkup') {
          Navigator.pushNamed(context, AppRoutes.appointments);
        } else if (a['type'] == 'missed') {
          Navigator.pushNamed(context, AppRoutes.reminderHistory);
        } else {
          _markRead(context, a);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
      decoration: BoxDecoration(
        color: tint == Colors.white ? Colors.white : tint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: tint,
                          child: Icon(_icon(a['type'] ?? ''), color: accent, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a['category'] ?? '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textGrey, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 4),
                              Text(a['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text(a['time'] ?? '', style: const TextStyle(color: AppColors.textGrey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isLowStockAlert)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _markRead(context, a),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryTeal,
                                side: const BorderSide(color: AppColors.primaryTeal),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('I Got It',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                _markRead(context, a);
                                Navigator.pushNamed(
                                    context, AppRoutes.medicationList);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primaryTeal,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text('View Medication',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Color _color(String key) {
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

  Color _tint(String key) {
    switch (key) {
      case 'red':
        return const Color(0xFFFFEBEE);
      case 'orange':
        return const Color(0xFFFFF3E0);
      default:
        return Colors.white;
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'drug':
        return Icons.warning_amber_rounded;
      case 'allergy':
        return Icons.shield_outlined;
      case 'missed':
        return Icons.medication_rounded;
      case 'checkup':
        return Icons.local_hospital_outlined;
      default:
        return Icons.info_outline;
    }
  }
}
