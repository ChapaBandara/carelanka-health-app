import 'dart:convert';
import 'dart:typed_data';

import 'package:carelanka_app/main.dart' show navigatorKey;
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ---------------------------------------------------------------------------
// Top-level background notification action handler
// Must be top-level (not a class method) so it can run in a background isolate.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> _onBackgroundNotificationAction(
    NotificationResponse response) async {
  try {
    // Firebase must be initialised in the background isolate.
    await Firebase.initializeApp();
  } catch (_) {
    // Already initialised — safe to ignore.
  }

  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;

  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    final medicationId = data['medicationId'] as String? ?? '';
    final medicationName = data['medicationName'] as String? ?? '';
    final dosage = data['dosage'] as String? ?? '';
    final illnessId = data['illnessId'] as String? ?? '';
    final userId = data['userId'] as String? ?? '';
    final timeStr = data['scheduledTime'] as String? ?? '';

    if (medicationId.isEmpty || userId.isEmpty) return;

    final now = DateTime.now();
    DateTime scheduledTime = now;
    try {
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
    } catch (_) {}

    final actionId = response.actionId ?? '';
    final reminder = ReminderService();
    final adherence = AdherenceService();

    if (actionId.startsWith('taken_')) {
      try {
        await reminder.logReminderAction(
          userId: userId,
          medicationId: medicationId,
          illnessId: illnessId,
          scheduledTime: scheduledTime,
          status: 'confirmed',
          actualResponseTime: now,
          medicationName: medicationName,
          medicationDosage: dosage,
        );
      } catch (_) {}
      try {
        await adherence.decrementStock(medicationId, userId);
      } catch (_) {}
    } else if (actionId.startsWith('snooze_')) {
      try {
        await reminder.logReminderAction(
          userId: userId,
          medicationId: medicationId,
          illnessId: illnessId,
          scheduledTime: scheduledTime,
          status: 'snoozed',
          actualResponseTime: now,
          medicationName: medicationName,
          medicationDosage: dosage,
        );
      } catch (_) {}
      // Reschedule a one-shot notification for 15 minutes from now.
      try {
        await NotificationService.instance.scheduleSnooze(
          medicationId: medicationId,
          snoozeDurationMinutes: 15,
          payload: payload,
        );
      } catch (_) {}
    } else if (actionId.startsWith('skip_')) {
      try {
        await reminder.logReminderAction(
          userId: userId,
          medicationId: medicationId,
          illnessId: illnessId,
          scheduledTime: scheduledTime,
          status: 'skipped',
          actualResponseTime: now,
          medicationName: medicationName,
          medicationDosage: dosage,
        );
      } catch (_) {}
    }
    // If actionId is empty, the user tapped the notification body — navigate
    // to the taking-medication screen (handled in foreground via navigatorKey).
  } catch (_) {}
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onForegroundNotificationResponse,
      // Background / terminated app handler — must be the top-level function.
      onDidReceiveBackgroundNotificationResponse:
          _onBackgroundNotificationAction,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  // ── Foreground response handler ──────────────────────────────────────────

  void _onForegroundNotificationResponse(NotificationResponse response) {
    // Action-button taps (foreground) — delegate to the same shared handler.
    if (response.actionId != null && response.actionId!.isNotEmpty) {
      _onBackgroundNotificationAction(response);
      return;
    }
    // Plain tap — navigate to taking-medication screen.
    _handlePayload(response.payload);
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      // Support both JSON (new) and legacy pipe-delimited (old) payloads.
      Map<String, dynamic> data;
      if (payload.startsWith('{')) {
        data = jsonDecode(payload) as Map<String, dynamic>;
      } else {
        // Legacy pipe-delimited: "medId|name|dosage|condition|millis|mealTiming|logId"
        final parts = payload.split('|');
        if (parts.length < 5) return;
        data = {
          'medicationId': parts[0],
          'medicationName': parts[1],
          'dosage': parts[2],
          'condition': parts[3],
          'scheduledTimeMillis': int.tryParse(parts[4]) ?? 0,
          'mealTiming': parts.length > 5 ? parts[5] : 'anytime',
          'logId': parts.length > 6 ? parts[6] : null,
        };
      }

      final medicationId = data['medicationId'] as String? ?? '';
      final medicationName = data['medicationName'] as String? ?? '';
      if (medicationId.isEmpty || medicationName.isEmpty) return;

      final dosage = data['dosage'] as String? ?? '';
      final condition = data['condition'] as String? ??
          data['illnessName'] as String? ?? '';
      final mealTiming =
          data['mealTiming'] as String? ?? 'anytime';
      final logId = data['logId'] as String?;

      // Resolve scheduled time from either millis or "HH:mm" string.
      DateTime scheduledAt;
      final millis = data['scheduledTimeMillis'] as int?;
      if (millis != null && millis > 0) {
        scheduledAt = DateTime.fromMillisecondsSinceEpoch(millis);
      } else {
        final timeStr = data['scheduledTime'] as String? ?? '';
        final parts = timeStr.split(':');
        final now = DateTime.now();
        if (parts.length >= 2) {
          scheduledAt = DateTime(now.year, now.month, now.day,
              int.tryParse(parts[0]) ?? now.hour,
              int.tryParse(parts[1]) ?? 0);
        } else {
          scheduledAt = now;
        }
      }

      final dose = DailyDoseItem(
        medicationId: medicationId,
        medicationName: medicationName,
        dosage: dosage,
        condition: condition,
        scheduledLabel: _formatTime(scheduledAt),
        scheduledAt: scheduledAt,
        status: 'pending',
        mealTiming: mealTiming,
        logId: logId,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState
            ?.pushNamed('/taking-medication', arguments: dose);
      });
    } catch (_) {}
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    return '$displayHour:$minute $period';
  }

  // ── User preference helpers ──────────────────────────────────────────────

  Future<bool> _getVibrateEnabled(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return doc.data()?['vibrateEnabled'] as bool? ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> _vibrateForCurrentUser() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || userId.isEmpty) return true;
    return _getVibrateEnabled(userId);
  }

  // ── Main medication reminder scheduler ──────────────────────────────────

  /// Schedules full-screen alarm-style notifications for each time in
  /// [timeStrings]. Shows three action buttons: Taken / Snooze 15 min / Skip.
  /// Works when the app is open, closed, or the phone is locked.
  Future<void> scheduleMedicationReminders({
    required String medicationId,
    required String title,
    required List<String> timeStrings,
    String dosage = '',
    String condition = '',
    String mealTiming = 'anytime',
    // Extra fields forwarded to the JSON payload so the background handler
    // can log the dose without querying Firestore for the medication details.
    String userId = '',
    String illnessId = '',
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();

    var id = medicationId.hashCode.abs() % 100000;
    final now = DateTime.now();

    for (final timeStr in timeStrings) {
      final parts = _parseTime(timeStr.trim());
      if (parts == null) continue;

      final scheduled = _nextInstance(parts.$1, parts.$2);
      final scheduledDt =
          DateTime(now.year, now.month, now.day, parts.$1, parts.$2);

      // JSON payload — richer than pipe-delimited, supports background handler.
      final payload = jsonEncode({
        'medicationId': medicationId,
        'medicationName': title,
        'dosage': dosage,
        'condition': condition,
        'illnessName': condition,
        'illnessId': illnessId,
        'userId': userId,
        'mealTiming': mealTiming,
        'scheduledTime': timeStr.trim(),
        'scheduledTimeMillis': scheduledDt.millisecondsSinceEpoch,
        'action': 'medication_reminder',
      });

      final androidDetails = AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        channelDescription: 'CareLanka medication reminders',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        playSound: true,
        enableVibration: vibrate,
        vibrationPattern: vibrate
            ? Int64List.fromList([0, 500, 200, 500, 200, 500])
            : null,
        ongoing: false,
        autoCancel: false,
        // Three action buttons visible on the notification and lock screen.
        actions: [
          AndroidNotificationAction(
            'taken_$medicationId',
            'Taken ✓',
            showsUserInterface: true,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'snooze_$medicationId',
            'Snooze 15 min',
            showsUserInterface: false,
            cancelNotification: true,
          ),
          AndroidNotificationAction(
            'skip_$medicationId',
            'Skip',
            showsUserInterface: false,
            cancelNotification: true,
          ),
        ],
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      await _zonedSchedule(
        id: id++,
        scheduledDate: scheduled,
        channelId: 'medication_reminders',
        channelName: 'Medication Reminders',
        title: 'Time for your medication 💊',
        body: dosage.isNotEmpty
            ? '$title $dosage${condition.isNotEmpty ? ' — $condition' : ''}'
            : '$title${condition.isNotEmpty ? ' — $condition' : ''}',
        matchDateTimeComponents: DateTimeComponents.time,
        notificationDetails: details,
        payload: payload,
      );
    }
  }

  // ── Cancel reminders ─────────────────────────────────────────────────────

  Future<void> cancelMedicationReminders(
    String medicationId, {
    int timeCount = 10,
  }) async {
    await initialize();
    var id = medicationId.hashCode.abs() % 100000;
    for (var i = 0; i < timeCount; i++) {
      await _plugin.cancel(id: id++);
    }
  }

  // ── Appointment reminders ────────────────────────────────────────────────

  Future<void> scheduleAppointmentReminders({
    required String appointmentId,
    required String title,
    required DateTime appointmentTime,
    List<Duration> offsets = const [
      Duration(hours: 2),
      Duration(days: 1),
    ],
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'appointment_reminders',
        'Appointment Reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrate,
        sound: const RawResourceAndroidNotificationSound('notification'),
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    var id = appointmentId.hashCode.abs() % 200000;
    for (final offset in offsets) {
      final when = appointmentTime.subtract(offset);
      if (when.isBefore(DateTime.now())) continue;
      await _zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        channelId: 'appointment_reminders',
        channelName: 'Appointment Reminders',
        title: 'Appointment reminder',
        body: title,
        notificationDetails: details,
      );
    }
  }

  // ── Snooze ───────────────────────────────────────────────────────────────

  /// Schedules a one-shot snooze notification [snoozeDurationMinutes] from now.
  /// Pass [payload] to forward the original medication payload so action buttons
  /// on the snoozed notification still log correctly.
  Future<void> scheduleSnooze({
    required String medicationId,
    int snoozeDurationMinutes = 15,
    String? payload,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();

    // Re-use action buttons on the snoozed notification too.
    final androidDetails = AndroidNotificationDetails(
      'medication_reminders',
      'Medication Reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: vibrate,
      vibrationPattern: vibrate
          ? Int64List.fromList([0, 500, 200, 500, 200, 500])
          : null,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.alarm,
      ongoing: false,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          'taken_$medicationId',
          'Taken ✓',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'snooze_$medicationId',
          'Snooze 15 min',
          showsUserInterface: false,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'skip_$medicationId',
          'Skip',
          showsUserInterface: false,
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    final snoozeTime =
        DateTime.now().add(Duration(minutes: snoozeDurationMinutes));
    final tzSnooze = tz.TZDateTime.from(snoozeTime, tz.local);
    await _zonedSchedule(
      id: 600000 + (medicationId.hashCode.abs() % 10000),
      scheduledDate: tzSnooze,
      channelId: 'medication_reminders',
      channelName: 'Medication Reminders',
      title: 'Snoozed medication reminder 💊',
      body: 'Your snoozed dose is due now.',
      notificationDetails: details,
      payload: payload,
    );
  }

  // ── One-shot show helpers ─────────────────────────────────────────────────

  Future<void> showCheckupSuggestion({required int daysSinceCheckup}) async {
    await initialize();
    const id = 900001;
    final vibrate = await _vibrateForCurrentUser();
    await _plugin.show(
      id: id,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'checkup_suggestions',
          'Checkup Suggestions',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: vibrate,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      title: 'Checkup reminder',
      body:
          "You haven't had a checkup in $daysSinceCheckup days. Tap to schedule a visit.",
    );
  }

  Future<void> showLowStockNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    final id = 800000 + (title.hashCode.abs() % 10000);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'stock_warnings',
          'Stock Warnings',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: vibrate,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showMissedDoseNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    final id = 700000 + (title.hashCode.abs() % 10000);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'missed_doses',
          'Missed Doses',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: vibrate,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showAdherenceReportNotification({
    required double adherenceScore,
    required String period,
  }) async {
    await initialize();
    const id = 500001;
    final isGood = adherenceScore >= 80;
    final title = isGood
        ? '$period Health Report — Great job! 🎉'
        : '$period Health Report — Keep going! 💪';
    final body = isGood
        ? 'You took ${adherenceScore.round()}% of your doses on time. '
            'Excellent consistency!'
        : 'You took ${adherenceScore.round()}% of your doses. '
            "Every dose matters. Don't give up!";
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'health_reports',
          'Health Reports',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required NotificationDetails notificationDetails,
    DateTimeComponents? matchDateTimeComponents,
    String? payload,
  }) async {
    var mode = await _preferredAndroidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: mode,
        matchDateTimeComponents: matchDateTimeComponents,
        title: title,
        body: body,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted' ||
          mode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }
      // Fallback to inexact if exact alarm permission was denied.
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        title: title,
        body: body,
        payload: payload,
      );
    }
  }

  Future<AndroidScheduleMode> _preferredAndroidScheduleMode() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;
    final canExact = await android.canScheduleExactNotifications();
    if (canExact == true) return AndroidScheduleMode.exactAllowWhileIdle;
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  (int, int)? _parseTime(String input) {
    final lower = input.toLowerCase();
    final match =
        RegExp(r'(\d{1,2}):?(\d{2})?\s*(am|pm)?').firstMatch(lower);
    if (match == null) return null;
    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2) ?? '0');
    final ampm = match.group(3);
    if (ampm == 'pm' && hour < 12) hour += 12;
    if (ampm == 'am' && hour == 12) hour = 0;
    return (hour, minute);
  }

  tz.TZDateTime _nextInstance(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
