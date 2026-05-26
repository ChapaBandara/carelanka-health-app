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
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: scheduled,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        title: 'Medication reminder',
        body: title,
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
      await _plugin.zonedSchedule(
        id: id++,
        scheduledDate: tz.TZDateTime.from(when, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'appointment_reminders',
            'Appointment Reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: 'Appointment reminder',
        body: title,
      );
    }
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
}
