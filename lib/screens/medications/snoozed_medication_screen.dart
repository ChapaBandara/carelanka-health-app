import 'dart:async';

import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #32 — Snoozed medication countdown screen.
class SnoozedMedicationScreen extends StatefulWidget {
  const SnoozedMedicationScreen({super.key});

  @override
  State<SnoozedMedicationScreen> createState() => _SnoozedMedicationScreenState();
}

class _SnoozedMedicationScreenState extends State<SnoozedMedicationScreen> {
  Timer? _timer;
  Duration _remaining = const Duration(minutes: 15);
  String _remindAt = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCountdown());
  }

  void _startCountdown() {
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final snoozeUntil = map['snoozeUntil'] as DateTime?;
    if (snoozeUntil != null) {
      _remaining = snoozeUntil.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
      _remindAt = DateFormat.jm().format(snoozeUntil);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_remaining.inSeconds > 0) {
          _remaining -= const Duration(seconds: 1);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _countdown {
    final m = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.activeScopeId;
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{};
    final argMedicationId = map['medicationId'] as String? ?? '';
    final argMedicationName = map['medicationName'] as String? ?? map['name'] as String? ?? '';
    final argCondition = map['condition'] as String? ?? '';
    final argScheduledTime = map['scheduledTime'] as DateTime?;
    final argDosage = map['dosage'] as String? ?? '';
    final argLogId = map['logId'] as String? ?? '';

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('reminder_logs')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final allDocs = snapshot.data?.docs ?? [];
        final docs = allDocs
            .where((d) => (d.data()['status'] as String? ?? '') == 'snoozed')
            .toList()
          ..sort((a, b) {
            final aTime = a.data()['scheduledTime'] as Timestamp?;
            final bTime = b.data()['scheduledTime'] as Timestamp?;
            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

        final first = docs.isNotEmpty ? docs.first.data() : <String, dynamic>{};
        final scheduledAt = (first['scheduledTime'] as Timestamp?)?.toDate() ?? argScheduledTime;
        final remindAt = _remindAt.isNotEmpty
            ? _remindAt
            : (scheduledAt != null ? DateFormat.jm().format(scheduledAt) : '');

        return Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2463), Color(0xFF008B9C), Color(0xFF00A8A8)],
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
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8EAF6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.schedule_rounded, size: 48, color: Color(0xFF5C6BC0)),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'Reminder Snoozed',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "We'll remind you again at $remindAt",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 15),
                    ),
                    const Spacer(),
                    Text(
                      _countdown,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(flex: 2),
                    OutlinedButton(
                      onPressed: () async {
                        final firstDocData = docs.isNotEmpty ? docs.first.data() : <String, dynamic>{};
                        final medicationId = (firstDocData['medicationId'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationId'] as String)
                            : argMedicationId;
                        final medicationName = (firstDocData['medicationName'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationName'] as String)
                            : argMedicationName;
                        final condition = (firstDocData['condition'] as String? ?? '').isNotEmpty
                            ? (firstDocData['condition'] as String)
                            : argCondition;
                        final scheduledTime = (firstDocData['scheduledTime'] as Timestamp?)?.toDate() ??
                            argScheduledTime ??
                            DateTime.now();
                        final dosage = (firstDocData['medicationDosage'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationDosage'] as String)
                            : argDosage;
                        final existingLogId = docs.isNotEmpty
                            ? docs.first.id
                            : (argLogId.isNotEmpty ? argLogId : null);

                        final now = DateTime.now();
                        final latency = now.difference(scheduledTime).inMinutes.clamp(0, 999);

                        await ReminderService().logDose(
                          userId: userId,
                          medicationId: medicationId,
                          medicationName: medicationName,
                          condition: condition,
                          scheduledTime: scheduledTime,
                          status: 'confirmed',
                          responseLatencyMinutes: latency,
                          existingLogId: existingLogId,
                          medicationDosage: dosage,
                        );

                        await AdherenceService().decrementStock(medicationId, userId);
                        await NotificationService.instance.cancelSnooze(medicationId);

                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(
                          context,
                          AppRoutes.confirmedMedication,
                          arguments: {
                            'name': medicationName,
                            'takenAt': DateFormat.jm().format(now),
                            'latency': latency,
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      child: const Text(
                        'Take it now instead',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () async {
                        final firstDocData = docs.isNotEmpty ? docs.first.data() : <String, dynamic>{};
                        final medicationId = (firstDocData['medicationId'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationId'] as String)
                            : argMedicationId;
                        final medicationName = (firstDocData['medicationName'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationName'] as String)
                            : argMedicationName;
                        final condition = (firstDocData['condition'] as String? ?? '').isNotEmpty
                            ? (firstDocData['condition'] as String)
                            : argCondition;
                        final scheduledTime = (firstDocData['scheduledTime'] as Timestamp?)?.toDate() ??
                            argScheduledTime ??
                            DateTime.now();
                        final dosage = (firstDocData['medicationDosage'] as String? ?? '').isNotEmpty
                            ? (firstDocData['medicationDosage'] as String)
                            : argDosage;
                        final existingLogId = docs.isNotEmpty
                            ? docs.first.id
                            : (argLogId.isNotEmpty ? argLogId : null);

                        await ReminderService().logDose(
                          userId: userId,
                          medicationId: medicationId,
                          medicationName: medicationName,
                          condition: condition,
                          scheduledTime: scheduledTime,
                          status: 'skipped',
                          existingLogId: existingLogId,
                          medicationDosage: dosage,
                        );

                        await NotificationService.instance.cancelSnooze(medicationId);

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Dose skipped'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.8),
                        minimumSize: const Size(double.infinity, 52),
                      ),
                      child: const Text(
                        'Skip This Dose',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          decoration: TextDecoration.underline,
                        ),
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
