class DailyDoseItem {
  const DailyDoseItem({
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.condition,
    required this.scheduledLabel,
    required this.scheduledAt,
    required this.status,
    this.actionLabel,
    this.mealTiming = '',
    this.latencyMinutes,
    this.logId,
    this.snoozeUntil,
  });

  final String medicationId;
  final String medicationName;
  final String dosage;
  final String condition;
  final String scheduledLabel;
  final DateTime scheduledAt;
  final String status;
  final String? actionLabel;
  final String mealTiming;
  final int? latencyMinutes;
  final String? logId;
  final DateTime? snoozeUntil;

  String get displayDosage {
    if (dosage.isEmpty) return '';
    return dosage;
  }
}
