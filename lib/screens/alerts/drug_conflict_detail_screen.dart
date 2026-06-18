import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/alert_service.dart';
import 'package:flutter/material.dart';

class DrugConflictDetailScreen extends StatefulWidget {
  const DrugConflictDetailScreen({super.key});

  @override
  State<DrugConflictDetailScreen> createState() => _DrugConflictDetailScreenState();
}

class _DrugConflictDetailScreenState extends State<DrugConflictDetailScreen> {
  bool _expanded = false;

  Map<String, String>? _alert(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) return args;
    if (args is Map) {
      return args.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    }
    return null;
  }

  ({String name, String dosage}) _parseMedication(String message, int index) {
    final conflictMatch = RegExp(r'Conflicts with:\s*([^.]+)', caseSensitive: false).firstMatch(message);
    final allergyMatch = RegExp(r'allergic to:\s*(.+)', caseSensitive: false).firstMatch(message);
    final dosageMatch = RegExp(
      r'(\d+\s*(?:mg|mcg|g|ml|IU|units?))',
      caseSensitive: false,
    ).allMatches(message).map((m) => m.group(1) ?? '').where((d) => d.isNotEmpty).toList();

    if (index == 0) {
      return (
        name: 'Your medication',
        dosage: dosageMatch.isNotEmpty ? dosageMatch.first : '—',
      );
    }

    if (conflictMatch != null) {
      return (
        name: conflictMatch.group(1)?.trim() ?? 'Medication',
        dosage: dosageMatch.length > 1 ? dosageMatch[1] : '—',
      );
    }

    if (allergyMatch != null) {
      return (
        name: allergyMatch.group(1)?.trim() ?? 'Allergen',
        dosage: '—',
      );
    }

    return (name: 'Medication', dosage: '—');
  }

  Future<void> _markRead(BuildContext context, Map<String, String> alert) async {
    final alertId = alert['alertId'];
    if (alertId == null || alertId.isEmpty) return;
    try {
      await AlertService().markAsRead(alertId);
      if (context.mounted) {
        showFirebaseSuccessSnackBar(context, 'Alert marked as read');
        Navigator.maybePop(context);
      }
    } catch (e) {
      if (context.mounted) {
        showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alert = _alert(context);
    final message = alert?['title'] ?? '';
    final detectedAt = alert?['time'] ?? '';
    final firstMed = _parseMedication(message, 0);
    final secondMed = _parseMedication(message, 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.navy),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 80,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Drug Conflict Detected',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'These medications in your list may interact dangerously',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textGrey,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Conflicting Medications',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE8E8E8)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _medicationTile(firstMed.name, firstMed.dosage),
                          const SizedBox(height: 12),
                          const Icon(Icons.swap_vert, color: AppColors.textGrey, size: 28),
                          const SizedBox(height: 12),
                          _medicationTile(secondMed.name, secondMed.dosage),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Text(
                        'Risk Level: HIGH',
                        style: TextStyle(
                          color: AppColors.errorRed,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Material(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'What does this mean?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    _expanded ? Icons.expand_less : Icons.expand_more,
                                    color: AppColors.textGrey,
                                  ),
                                ],
                              ),
                              if (_expanded) ...[
                                const SizedBox(height: 12),
                                Text(
                                  message.isNotEmpty
                                      ? message
                                      : 'No additional details available.',
                                  style: const TextStyle(
                                    color: AppColors.textGrey,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      detectedAt.isNotEmpty ? 'Detected: $detectedAt' : 'Detected: —',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: alert == null ? null : () => _markRead(context, alert),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: CareLankaGradients.primaryHorizontal,
                          ),
                          child: const Center(
                            child: Text(
                              'Mark as Read',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryTeal,
                        side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.addAppointment),
                      child: const Text(
                        'Book Doctor Appointment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Call My Doctor',
                      style: TextStyle(
                        color: AppColors.primaryTeal,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationTile(String name, String dosage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dosage,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
