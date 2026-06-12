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
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  Future<void> scheduleMedicationReminders({
    required String medicationId,
    required String title,
    required List<String> timeStrings,
  }) async {
    await initialize();
    var id = medicationId.hashCode.abs() % 100000;
    for (final timeStr in timeStrings) {
      final parts = _parseTime(timeStr.trim());
      if (parts == null) continue;
      final scheduled = _nextInstance(parts.$1, parts.$2);
      await _zonedSchedule(
        id: id++,
        scheduledDate: scheduled,
        channelId: 'medication_reminders',
        channelName: 'Medication Reminders',
        title: 'Medication reminder',
        body: title,
        matchDateTimeComponents: DateTimeComponents.time,
      );
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
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    var mode = await _preferredAndroidScheduleMode();
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: mode,
        matchDateTimeComponents: matchDateTimeComponents,
        title: title,
        body: body,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted' ||
          mode == AndroidScheduleMode.inexactAllowWhileIdle) {
        rethrow;
      }
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        title: title,
        body: body,
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
    await _plugin.show(
      id: id,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'checkup_suggestions',
          'Checkup Suggestions',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      title: 'Checkup reminder',
      body: "You haven't had a checkup in $daysSinceCheckup days. Tap to schedule a visit.",
    );
  }
}
