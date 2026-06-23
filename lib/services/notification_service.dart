import 'package:carelanka_app/main.dart' show navigatorKey;
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
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
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  void _onNotificationTapped(NotificationResponse response) {
    _handlePayload(response.payload);
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    // Background handler — limited functionality
  }

  void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;

    try {
      // Parse payload: "medicationId|medicationName|dosage|condition|scheduledTimeMillis|mealTiming|logId"
      final parts = payload.split('|');
      if (parts.length < 5) return;

      final medicationId = parts[0];
      final medicationName = parts[1];
      final dosage = parts[2];
      final condition = parts[3];
      final scheduledMillis = int.tryParse(parts[4]) ?? 0;
      final mealTiming = parts.length > 5 ? parts[5] : 'anytime';
      final logId = parts.length > 6 ? parts[6] : null;

      if (medicationId.isEmpty || medicationName.isEmpty) return;

      final scheduledAt = scheduledMillis > 0
          ? DateTime.fromMillisecondsSinceEpoch(scheduledMillis)
          : DateTime.now();

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

      // Navigate using the global navigator key
      // Small delay to ensure app is mounted
      Future.delayed(const Duration(milliseconds: 500), () {
        navigatorKey.currentState?.pushNamed(
          '/taking-medication',
          arguments: dose,
        );
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

  Future<void> scheduleMedicationReminders({
    required String medicationId,
    required String title,
    required List<String> timeStrings,
    String dosage = '',
    String condition = '',
    String mealTiming = 'anytime',
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrate,
        fullScreenIntent: true,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
    var id = medicationId.hashCode.abs() % 100000;
    final now = DateTime.now();
    for (final timeStr in timeStrings) {
      final parts = _parseTime(timeStr.trim());
      if (parts == null) continue;
      final scheduled = _nextInstance(parts.$1, parts.$2);
      final scheduledDt = DateTime(
        now.year, now.month, now.day, parts.$1, parts.$2);
      final payloadMillis = scheduledDt.millisecondsSinceEpoch;
      final payload = '$medicationId|$title|$dosage|$condition|$payloadMillis|$mealTiming|';
      await _zonedSchedule(
        id: id++,
        scheduledDate: scheduled,
        channelId: 'medication_reminders',
        channelName: 'Medication Reminders',
        title: 'Medication reminder',
        body: title,
        matchDateTimeComponents: DateTimeComponents.time,
        notificationDetails: details,
        payload: payload,
      );
    }
  }

  /// Cancels all scheduled notifications for [medicationId].
  ///
  /// Uses the same ID derivation as [scheduleMedicationReminders] so the IDs
  /// line up correctly. [timeCount] should be at least as large as the number
  /// of scheduled times (defaults to 10 to be safe).
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
      iOS: DarwinNotificationDetails(
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
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.inexactAllowWhileIdle;
    final canExact = await android.canScheduleExactNotifications();
    if (canExact == true) return AndroidScheduleMode.exactAllowWhileIdle;
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  (int, int)? _parseTime(String input) {
    final lower = input.toLowerCase();
    final match = RegExp(r'(\d{1,2}):?(\d{2})?\s*(am|pm)?').firstMatch(lower);
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
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

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
      body: "You haven't had a checkup in $daysSinceCheckup days. Tap to schedule a visit.",
    );
  }

  /// Shows an immediate low-stock warning notification.
  Future<void> showLowStockNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    // Derive a stable ID from the title so the same medication doesn't spam.
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

  /// Shows an immediate missed-dose notification.
  Future<void> showMissedDoseNotification({
    required String title,
    required String body,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    // Stable ID derived from title so the same dose doesn't spam.
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
    final id = 500001;
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

  /// Schedules a one-shot snooze notification [snoozeDurationMinutes] from now.
  Future<void> scheduleSnooze({
    required String medicationId,
    int snoozeDurationMinutes = 15,
  }) async {
    await initialize();
    final vibrate = await _vibrateForCurrentUser();
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders',
        'Medication Reminders',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: vibrate,
        fullScreenIntent: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(),
    );
    final snoozeTime = DateTime.now().add(Duration(minutes: snoozeDurationMinutes));
    final tzSnooze = tz.TZDateTime.from(snoozeTime, tz.local);
    await _zonedSchedule(
      id: 600000 + (medicationId.hashCode.abs() % 10000),
      scheduledDate: tzSnooze,
      channelId: 'medication_reminders',
      channelName: 'Medication Reminders',
      title: 'Medication reminder (snoozed)',
      body: 'Your snoozed dose is due now.',
      notificationDetails: details,
    );
  }
}
