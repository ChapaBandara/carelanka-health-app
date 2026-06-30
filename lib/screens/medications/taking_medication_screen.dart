import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/models/daily_dose_item.dart';
import 'package:carelanka_app/services/reminder_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #28 — Taking Medication full-screen reminder.
class TakingMedicationScreen extends StatelessWidget {
  const TakingMedicationScreen({super.key});

  static String _mealLabel(String value) {
    switch (value.toLowerCase()) {
      case 'before_meals':
        return 'Before Meal';
      case 'after_meals':
        return 'After Meal';
      case 'with_meals':
        return 'With Meal';
      default:
        return 'Anytime';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dose = ModalRoute.of(context)?.settings.arguments;
    if (dose is! DailyDoseItem) {
      return const Scaffold(body: Center(child: Text('Invalid dose')));
    }

    final meal = _mealLabel(dose.mealTiming);
    final subtitle = dose.dosage.isEmpty ? '' : dose.dosage;

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
                const SizedBox(height: 24),
                const Text(
                  'TIME FOR MEDICATION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(flex: 2),
                Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.medication_outlined, size: 52, color: AppColors.primaryTeal),
                ),
                const SizedBox(height: 28),
                Text(
                  dose.medicationName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16),
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.navy.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(meal, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
                if (dose.condition.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    dose.condition,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                  ),
                ],
                const Spacer(flex: 3),
                _pillButton(
                  label: 'Take Now',
                  icon: Icons.check_rounded,
                  background: Colors.white,
                  foreground: AppColors.primaryTeal,
                  onTap: () => _takeNow(context, dose),
                ),
                const SizedBox(height: 14),
                _pillButton(
                  label: 'Snooze (15 min)',
                  icon: Icons.schedule_rounded,
                  background: Colors.white.withValues(alpha: 0.22),
                  foreground: Colors.white,
                  onTap: () => _snooze(context, dose),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: () => _skip(context, dose),
                  icon: const Icon(Icons.close, color: Color(0xFFFF8A80), size: 20),
                  label: const Text(
                    'Skip This Dose',
                    style: TextStyle(color: Color(0xFFFF8A80), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(32),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 22),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: foreground, fontSize: 17, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _takeNow(BuildContext context, DailyDoseItem dose) async {
    final userId = context.activeScopeId;
    final now = DateTime.now();
    final latency = now.difference(dose.scheduledAt).inMinutes.clamp(0, 999);
    await ReminderService().logDose(
      userId: userId,
      medicationId: dose.medicationId,
      medicationName: dose.medicationName,
      condition: dose.condition,
      scheduledTime: dose.scheduledAt,
      status: 'confirmed',
      responseLatencyMinutes: latency,
      existingLogId: dose.logId,
    );
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.confirmedMedication,
      arguments: {
        'name': dose.medicationName,
        'takenAt': DateFormat.jm().format(now),
        'latency': latency,
      },
    );
  }

  Future<void> _snooze(BuildContext context, DailyDoseItem dose) async {
    final userId = context.activeScopeId;
    final snoozeUntil = DateTime.now().add(const Duration(minutes: 15));
    await ReminderService().logDose(
      userId: userId,
      medicationId: dose.medicationId,
      medicationName: dose.medicationName,
      condition: dose.condition,
      scheduledTime: dose.scheduledAt,
      status: 'snoozed',
      snoozeUntil: snoozeUntil,
      existingLogId: dose.logId,
    );
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.snoozedMedication,
      arguments: {
        'name': dose.medicationName,
        'remindAt': DateFormat.jm().format(snoozeUntil),
        'snoozeUntil': snoozeUntil,
      },
    );
  }

  Future<void> _skip(BuildContext context, DailyDoseItem dose) async {
    final userId = context.activeScopeId;
    await ReminderService().logDose(
      userId: userId,
      medicationId: dose.medicationId,
      medicationName: dose.medicationName,
      condition: dose.condition,
      scheduledTime: dose.scheduledAt,
      status: 'skipped',
      existingLogId: dose.logId,
    );
    if (context.mounted) Navigator.pop(context);
  }
}
