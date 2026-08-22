import 'dart:async';

import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/screens/family/family_screen.dart';
import 'package:carelanka_app/screens/home/dashboard_screen.dart';
import 'package:carelanka_app/screens/profile/profile_screen.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_bottom_nav.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final Set<String> _shownAppointmentsThisSession = {};

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 2);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateCheckupReminder());

    // Start polling for due medication reminders every 10 seconds.
    _reminderTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkDueReminders();
      _checkAppointmentReminders();
    });
    // Also run once immediately after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDueReminders();
      _checkDayBeforeAppointments();
      _checkAppointmentReminders();
    });
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
    if (kDebugMode) debugPrint('🕐 _checkDueReminders called at ${DateTime.now()}');
    final ownUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownUid == null || ownUid.isEmpty) return;

    final scopes = await FamilyService().fetchAllFamilyScopes(ownUid);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    for (final scope in scopes) {
      if (!mounted || _reminderDialogOpen) return;

      final medSnap = await FirebaseFirestore.instance
          .collection('medications')
          .where('userId', isEqualTo: scope.scopeId)
          .where('active', isEqualTo: true)
          .get();
      if (kDebugMode) debugPrint('💊 Found ${medSnap.docs.length} active medications for ${scope.scopeId} (${scope.patientName})');

      for (final doc in medSnap.docs) {
        if (!mounted || _reminderDialogOpen) return;
        final data = doc.data();
        final illnessId = data['illnessId'] as String? ?? '';

        // Skip medications whose illness is completed.
        if (illnessId.isNotEmpty) {
          try {
            final illnessDoc = await FirebaseFirestore.instance
                .collection('illnesses')
                .doc(illnessId)
                .get();
            final status = illnessDoc.data()?['status'] as String? ?? 'active';
            if (status == 'completed') continue;
          } catch (_) {}
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
          if (kDebugMode) debugPrint('⏰ Checking $timeStr → scheduled: $scheduledTime, diff: $diff min');
          // Trigger only within the window [0, 5] minutes after the due time.
          if (diff < 0 || diff > 5) continue;

          final sessionKey =
              '${doc.id}_${parsed.$1}_${parsed.$2}_${todayStart.toIso8601String()}';
          if (_shownThisSession.contains(sessionKey)) continue;

          // Check whether a reminder_log already exists for this dose window.
          QuerySnapshot<Map<String, dynamic>> existingSnap;
          try {
            existingSnap = await FirebaseFirestore.instance
                .collection('reminder_logs')
                .where('userId', isEqualTo: scope.scopeId)
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
          } catch (e) {
            if (kDebugMode) debugPrint('❌ Index query failed: $e');
            existingSnap = await FirebaseFirestore.instance
                .collection('reminder_logs')
                .where('userId', isEqualTo: scope.scopeId)
                .where('medicationId', isEqualTo: doc.id)
                .limit(10)
                .get();
            // Filter in Dart if index not ready
            final already = existingSnap.docs.any((d) {
              final st = d.data()['scheduledTime'];
              if (st is! Timestamp) return false;
              final dt = st.toDate();
              return dt.isAfter(scheduledTime.subtract(const Duration(minutes: 2))) &&
                     dt.isBefore(scheduledTime.add(const Duration(minutes: 2)));
            });
            if (already) {
              _shownThisSession.add(sessionKey);
              continue;
            }
            existingSnap = await FirebaseFirestore.instance
                .collection('reminder_logs')
                .limit(0)
                .get();
          }
          final existing = existingSnap;

          if (kDebugMode) debugPrint('🔍 Existing log check: found ${existing.docs.length} docs for $sessionKey');
          if (existing.docs.isNotEmpty) {
            _shownThisSession.add(sessionKey);
            continue;
          }

          if (kDebugMode) debugPrint('🚨 SHOWING REMINDER for $sessionKey at ${DateTime.now()}');
          _shownThisSession.add(sessionKey);
          _reminderDialogOpen = true;

          // Resolve condition name from illness document.
          String condition = '';
          if (illnessId.isNotEmpty) {
            try {
              final illnessDoc = await FirebaseFirestore.instance
                  .collection('illnesses')
                  .doc(illnessId)
                  .get();
              condition =
                  illnessDoc.data()?['illnessName'] as String? ?? '';
            } catch (_) {}
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

          final patientName = scope.isSelf ? '' : scope.patientName;
          final displayCondition = patientName.isNotEmpty
              ? 'For: $patientName${condition.isNotEmpty ? ' — $condition' : ''}'
              : condition;

          final dose = DailyDoseItem(
            medicationId: doc.id,
            medicationName: data['name'] as String? ?? 'Medication',
            dosage: data['dosage'] as String? ?? '',
            condition: displayCondition,
            scheduledLabel: timeStr,
            scheduledAt: scheduledTime,
            status: 'upcoming',
            mealTiming: data['mealTiming'] as String? ?? '',
            userId: scope.scopeId,
            patientName: patientName,
          );

          // Play sound for in-app reminder
          try {
            await NotificationService.instance.showImmediateReminder(
              medicationName: data['name'] as String? ?? 'Medication',
              dosage: data['dosage'] as String? ?? '',
              patientName: patientName,
            );
          } catch (_) {}

          await navState.pushNamed(
            AppRoutes.takingMedication,
            arguments: dose,
          );
          _reminderDialogOpen = false;
          if (kDebugMode) debugPrint('✅ REMINDER SCREEN DISMISSED for $sessionKey');
          return;
        }
      }
    }

    // Appointment reminder check loop across family scopes
    try {
      for (final scope in scopes) {
        final apptSnap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: scope.scopeId)
            .get();

        for (final doc in apptSnap.docs) {
          final data = doc.data();
          final dtField = data['dateTime'];
          if (dtField is! Timestamp) continue;

          final apptTime = dtField.toDate();
          final today = DateTime(now.year, now.month, now.day);
          final apptDay = DateTime(apptTime.year, apptTime.month, apptTime.day);
          final diffDays = apptDay.difference(today).inDays;
          if (diffDays != 0 && diffDays != 1) continue;

          final offsets = [120, 60, 30];
          for (final offset in offsets) {
            final scheduledReminderTime = apptTime.subtract(Duration(minutes: offset));
            final diffMinutes = now.difference(scheduledReminderTime).inMinutes;

            if (diffMinutes < 0 || diffMinutes > 5) continue;

            final sessionKey = '${doc.id}_${offset}_${today.toIso8601String()}';
            if (_shownAppointmentsThisSession.contains(sessionKey)) continue;

            _shownAppointmentsThisSession.add(sessionKey);

            final doctor = data['doctorName'] as String? ?? 'Doctor';
            final venue = data['hospital'] as String? ?? 'Venue';
            final apptNotificationId = 900000 + (doc.id.hashCode.abs() % 100000) + offset;

            try {
              await NotificationService.instance.showImmediateAppointmentReminder(
                id: apptNotificationId,
                doctorName: scope.isSelf ? doctor : '${scope.patientName}: $doctor',
                venue: venue,
                minutesRemaining: offset,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _checkAppointmentReminders() async {
    if (!mounted) return;
    final ownUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownUid == null || ownUid.isEmpty) return;

    final scopes = await FamilyService().fetchAllFamilyScopes(ownUid);
    final now = DateTime.now();

    for (final scope in scopes) {
      if (!mounted) return;
      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('userId', isEqualTo: scope.scopeId)
          .where('status', isNotEqualTo: 'completed')
          .get();

      for (final doc in snap.docs) {
        if (!mounted) return;
        final data = doc.data();
        final appointmentId = doc.id;

        // Appointments are stored with a single 'dateTime' Timestamp field.
        final dtField = data['dateTime'];
        if (dtField is! Timestamp) continue;

        final appointmentDateTime = dtField.toDate();
        final doctor = data['doctorName'] as String? ?? 'Doctor';
        final doctorName = scope.isSelf ? doctor : '${scope.patientName}: $doctor';

        // Check 2hr, 1hr, 30min before reminders
        for (final offsetMinutes in [120, 60, 30]) {
          final reminderTime = appointmentDateTime
              .subtract(Duration(minutes: offsetMinutes));
          final diff = now.difference(reminderTime).inMinutes;
          if (diff < 0 || diff > 5) continue;

          final sessionKey = '${appointmentId}_${offsetMinutes}mins';
          if (_shownAppointmentsThisSession.contains(sessionKey)) continue;

          _shownAppointmentsThisSession.add(sessionKey);

          final venue = data['hospital'] as String? ?? data['venue'] as String? ?? 'Hospital';
          final offsetText = offsetMinutes == 120
              ? '2 hours'
              : offsetMinutes == 60
                  ? '1 hour'
                  : '30 minutes';

          await NotificationService.instance.showAppointmentReminder(
            doctorName: doctorName,
            venue: venue,
            timeUntil: offsetText,
          );
          return;
        }

        // Day before reminder
        final tomorrow = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        final apptDay = DateTime(appointmentDateTime.year,
            appointmentDateTime.month, appointmentDateTime.day);

        if (apptDay == tomorrow) {
          final sessionKey = '${appointmentId}_day_before';
          if (_shownAppointmentsThisSession.contains(sessionKey)) continue;
          _shownAppointmentsThisSession.add(sessionKey);

          await NotificationService.instance.showAppointmentReminder(
            doctorName: doctorName,
            venue: data['hospital'] as String? ?? data['venue'] as String? ?? 'Hospital',
            timeUntil: 'tomorrow',
          );
        }
      }
    }
  }


  Future<void> _checkDayBeforeAppointments() async {
    if (!mounted) return;
    final ownUid = FirebaseAuth.instance.currentUser?.uid;
    if (ownUid == null || ownUid.isEmpty) return;

    try {
      final scopes = await FamilyService().fetchAllFamilyScopes(ownUid);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final scope in scopes) {
        final apptSnap = await FirebaseFirestore.instance
            .collection('appointments')
            .where('userId', isEqualTo: scope.scopeId)
            .get();

        for (final doc in apptSnap.docs) {
          final data = doc.data();
          final dtField = data['dateTime'];
          if (dtField is! Timestamp) continue;

          final apptTime = dtField.toDate();
          final apptDay = DateTime(apptTime.year, apptTime.month, apptTime.day);
          final diffDays = apptDay.difference(today).inDays;

          // If apptDay is tomorrow, then today is the day before the appointment!
          if (diffDays == 1) {
            final rawDoctor = data['doctorName'] as String? ?? 'Doctor';
            final doctor = scope.isSelf ? rawDoctor : '${scope.patientName}: $rawDoctor';
            final venue = data['hospital'] as String? ?? 'Venue';
            final timeStr = DateFormat.jm().format(apptTime);
            final apptNotificationId = 800000 + (doc.id.hashCode.abs() % 100000);

            try {
              await NotificationService.instance.showDayBeforeAppointmentNotification(
                id: apptNotificationId,
                doctorName: doctor,
                venue: venue,
                timeString: timeStr,
              );
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
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
