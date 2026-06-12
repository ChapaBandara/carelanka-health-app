import 'package:intl/intl.dart';

class MedicationScheduleHelper {
  static DateTime? parseTimeOnDay(String timeStr, DateTime day) {
    try {
      final parsed = DateFormat('h:mm a').parse(timeStr.trim());
      return DateTime(day.year, day.month, day.day, parsed.hour, parsed.minute);
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
