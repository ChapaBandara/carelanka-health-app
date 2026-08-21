import 'package:intl/intl.dart';

class MedicationScheduleHelper {
  static DateTime? parseTimeOnDay(String timeStr, DateTime day) {
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM)?', caseSensitive: false)
          .firstMatch(timeStr.trim());
      if (match == null) return null;
      var hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final ampm = match.group(3)?.toUpperCase();
      if (ampm == 'PM' && hour < 12) hour += 12;
      if (ampm == 'AM' && hour == 12) hour = 0;
      return DateTime(day.year, day.month, day.day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static int totalDosesToday(List<Map<String, dynamic>> medications, DateTime now) {
    var total = 0;
    for (final med in medications) {
      if (med['active'] != true) continue;
      final times = med['scheduledTimes'] as List? ?? [];
      total += times.length;
    }
    return total;
  }

  static ({String label, String name, String dosage})? nextDoseToday(
    List<Map<String, dynamic>> medications,
    DateTime now,
  ) {
    final upcoming = <({DateTime when, String name, String dosage})>[];
    for (final med in medications) {
      if (med['active'] != true) continue;
      final name = med['name'] as String? ?? 'Medication';
      final dosage = med['dosage'] as String? ?? '';
      final times = med['scheduledTimes'] as List? ?? [];
      for (final raw in times) {
        final when = parseTimeOnDay(raw.toString(), now);
        if (when != null && !when.isBefore(now)) {
          upcoming.add((when: when, name: name, dosage: dosage));
        }
      }
    }
    if (upcoming.isEmpty) return null;
    upcoming.sort((a, b) => a.when.compareTo(b.when));
    final next = upcoming.first;
    return (
      label: DateFormat.jm().format(next.when),
      name: next.name,
      dosage: next.dosage,
    );
  }
}
