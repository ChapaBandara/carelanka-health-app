import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #30 — Dose Confirmed success screen.
class ConfirmedMedicationScreen extends StatelessWidget {
  const ConfirmedMedicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.activeScopeId;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reminder_logs')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'confirmed')
          .orderBy('scheduledTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final first = docs.isNotEmpty ? docs.first.data() : <String, dynamic>{};
        final name = first['medicationName']?.toString() ?? 'Medication';
        final scheduled = (first['scheduledTime'] as Timestamp?)?.toDate();
        final takenAt = scheduled != null ? DateFormat.jm().format(scheduled) : '';
        final latency = (first['responseLatencyMinutes'] as int?) ?? 0;
        final timingText = latency > 0
            ? 'Taken $latency minute${latency == 1 ? '' : 's'} after reminder'
            : 'Taken on time';

        return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF008B9C), Color(0xFF00A8A8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Dose Confirmed!',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  '$name taken at $takenAt',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  timingText,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14),
                ),
                const SizedBox(height: 32),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    docs.isEmpty
                        ? 'No confirmed medications yet.'
                        : '${docs.length} confirmed medication${docs.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: AppColors.primaryTeal,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
                OutlinedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.reminderHistory,
                    (route) => route.isFirst || route.settings.name == AppRoutes.dashboard,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    "View Today's Medications",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
      },
    );
  }
}
