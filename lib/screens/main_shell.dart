import 'dart:async';

import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/screens/family/family_screen.dart';
import 'package:carelanka_app/screens/home/dashboard_screen.dart';
import 'package:carelanka_app/screens/profile/profile_screen.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka shell: Home, Family, Profile (matches UI folder bottom navigation).
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;

  // ── In-app polling reminder state ────────────────────────────────────────
  Timer? _reminderTimer;
  bool _reminderDialogOpen = false;
  final Set<String> _shownThisSession = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateCheckupReminder());

    // Start polling for due medication reminders every 30 seconds.
    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDueReminders();
    });
    // Also run once immediately after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkDueReminders());
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _evaluateCheckupReminder() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await CheckupService().evaluateForUser(userId);
  }

  // ── Polling check ─────────────────────────────────────────────────────────

  Future<void> _checkDueReminders() async {
    if (!mounted || _reminderDialogOpen) return;
    final uid = context.activeScopeId;
    if (uid.isEmpty) return;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final medSnap = await FirebaseFirestore.instance
        .collection('medications')
        .where('userId', isEqualTo: uid)
        .where('active', isEqualTo: true)
        .get();

    for (final doc in medSnap.docs) {
      if (!mounted || _reminderDialogOpen) return;
      final data = doc.data();
      final illnessId = data['illnessId'] as String? ?? '';

      // Skip medications whose illness is completed.
      if (illnessId.isNotEmpty) {
        final illnessDoc = await FirebaseFirestore.instance
            .collection('illnesses')
            .doc(illnessId)
            .get();
        final status = illnessDoc.data()?['status'] as String? ?? 'active';
        if (status == 'completed') continue;
      }

      final times = List<String>.from(data['scheduledTimes'] as List? ?? []);
      for (final timeStr in times) {
        final parsed = _parseReminderTime(timeStr);
        if (parsed == null) continue;

        final scheduledTime = DateTime(
          todayStart.year,
          todayStart.month,
          todayStart.day,
          parsed.$1,
          parsed.$2,
        );

        final diff = now.difference(scheduledTime).inMinutes;
        // Trigger only within the window [0, 2] minutes after the due time.
        if (diff < 0 || diff > 2) continue;

        final sessionKey =
            '${doc.id}_${parsed.$1}_${parsed.$2}_${todayStart.toIso8601String()}';
        if (_shownThisSession.contains(sessionKey)) continue;

        // Check whether a reminder_log already exists for this dose window.
        final existing = await FirebaseFirestore.instance
            .collection('reminder_logs')
            .where('userId', isEqualTo: uid)
            .where('medicationId', isEqualTo: doc.id)
            .where(
              'scheduledTime',
              isGreaterThanOrEqualTo: Timestamp.fromDate(
                  scheduledTime.subtract(const Duration(minutes: 2))),
            )
            .where(
              'scheduledTime',
              isLessThanOrEqualTo: Timestamp.fromDate(
                  scheduledTime.add(const Duration(minutes: 2))),
            )
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          _shownThisSession.add(sessionKey);
          continue;
        }

        _shownThisSession.add(sessionKey);
        _reminderDialogOpen = true;

        // Resolve condition name from illness document.
        String condition = '';
        if (illnessId.isNotEmpty) {
          final illnessDoc = await FirebaseFirestore.instance
              .collection('illnesses')
              .doc(illnessId)
              .get();
          condition =
              illnessDoc.data()?['illnessName'] as String? ?? '';
        }

        if (!mounted) {
          _reminderDialogOpen = false;
          return;
        }

        final navState = notificationNavigatorKey.currentState;
        if (navState == null) {
          _reminderDialogOpen = false;
          return;
        }

        final dose = DailyDoseItem(
          medicationId: doc.id,
          medicationName: data['name'] as String? ?? 'Medication',
          dosage: data['dosage'] as String? ?? '',
          condition: condition,
          scheduledLabel: timeStr,
          scheduledAt: scheduledTime,
          status: 'upcoming',
          mealTiming: data['mealTiming'] as String? ?? '',
        );

        await navState.pushNamed(
          AppRoutes.takingMedication,
          arguments: dose,
        );

        _reminderDialogOpen = false;
        return; // Show at most one reminder per check cycle.
      }
    }
  }

  /// Parses a time string such as "8:30 AM", "14:00", or "2:00 pm".
  /// Returns a (hour24, minute) record, or null on parse failure.
  (int, int)? _parseReminderTime(String timeStr) {
    final lower = timeStr.toLowerCase().trim();
    final match =
        RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)?').firstMatch(lower);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final ampm = match.group(3);
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    return (hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    const screens = [
      DashboardScreen(),
      FamilyScreen(),
      ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: CareLankaBottomNav(
        currentIndex: _index,
        onShellTap: (i) => setState(() => _index = i),
      ),
    );
  }
}
