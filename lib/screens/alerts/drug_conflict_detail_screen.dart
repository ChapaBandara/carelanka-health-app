import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/alert_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:flutter/material.dart';

class DrugConflictDetailScreen extends StatefulWidget {
  const DrugConflictDetailScreen({super.key});

  @override
  State<DrugConflictDetailScreen> createState() => _DrugConflictDetailScreenState();
}

class _DrugConflictDetailScreenState extends State<DrugConflictDetailScreen> {
  bool _expanded = true;
  List<Map<String, dynamic>> _medications = [];
  bool _loadingMeds = true;

  Map<String, String>? _alert(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, String>) return args;
    if (args is Map) {
      return args.map((key, value) => MapEntry(key.toString(), value?.toString() ?? ''));
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMedications());
  }

  Future<void> _loadMedications() async {
    final uid = context.activeScopeId;
    if (uid.isEmpty) {
      if (mounted) setState(() => _loadingMeds = false);
      return;
    }
    try {
      final meds = await MedicationService().watchMedications(uid).first;
      if (mounted) {
        setState(() {
          _medications = meds;
          _loadingMeds = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingMeds = false);
    }
  }

  ({String name, String dosage}) _medAt(int index, String message) {
    final alert = _alert(context);
    final newName = alert?['newMedicationName']?.trim() ?? '';
    final newDosage = alert?['newMedicationDosage']?.trim() ?? '';
    final rawConflicting = alert?['conflictingMedicationNames'] ?? '';
    final rawAllergies = alert?['matchedAllergies'] ?? '';
    final conflictingNames = rawConflicting
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final allergyNames = rawAllergies
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (index == 0 && newName.isNotEmpty) {
      return (name: newName, dosage: newDosage.isEmpty ? '—' : newDosage);
    }
    if (index == 1 && (conflictingNames.isNotEmpty || allergyNames.isNotEmpty)) {
      final otherName = conflictingNames.isNotEmpty ? conflictingNames.first : allergyNames.first;
      final dbMatch = _medications.where((m) {
        final n = (m['name'] as String? ?? '').toLowerCase();
        final o = otherName.toLowerCase();
        return n.contains(o) || o.contains(n);
      }).toList();
      if (dbMatch.isNotEmpty) {
        return (
          name: dbMatch.first['name'] as String? ?? otherName,
          dosage: dbMatch.first['dosage'] as String? ?? '—',
        );
      }
      return (name: otherName, dosage: '—');
    }

    if (conflictingNames.isEmpty && allergyNames.isNotEmpty) {
      final allergyName = allergyNames.first;
      final dbMatch = _medications.where((m) {
        final n = (m['name'] as String? ?? '').toLowerCase();
        final o = allergyName.toLowerCase();
        return n.contains(o) || o.contains(n);
      }).toList();
      if (dbMatch.isNotEmpty) {
        return (
          name: dbMatch.first['name'] as String? ?? allergyName,
          dosage: dbMatch.first['dosage'] as String? ?? '—',
        );
      }
      return (name: allergyName, dosage: '—');
    }

    final conflictMatch = RegExp(r'Conflicts with:\s*([^.]+)', caseSensitive: false).firstMatch(message);
    final allergyMatch = RegExp(r'allergic to:\s*(.+)', caseSensitive: false).firstMatch(message);
    final conflictingName = conflictMatch?.group(1)?.trim().toLowerCase() ?? '';
    final allergyName = allergyMatch?.group(1)?.trim().toLowerCase() ?? '';

    Map<String, dynamic>? matchMed(String needle) {
      if (needle.isEmpty) return null;
      for (final med in _medications) {
        final name = (med['name'] as String? ?? '').toLowerCase();
        if (name.contains(needle) || needle.contains(name)) return med;
      }
      return null;
    }

    if (index == 0) {
      final newest = _medications.isNotEmpty ? _medications.last : null;
      if (newest != null) {
        return (
          name: newest['name'] as String? ?? 'Your medication',
          dosage: newest['dosage'] as String? ?? '—',
        );
      }
      return (name: 'Your medication', dosage: '—');
    }

    final other = matchMed(conflictingName) ?? matchMed(allergyName);
    if (other != null) {
      return (
        name: other['name'] as String? ?? 'Medication',
        dosage: other['dosage'] as String? ?? '—',
      );
    }

    if (conflictingName.isNotEmpty) {
      final display = conflictMatch!.group(1)!.trim();
      return (name: display, dosage: '—');
    }
    if (allergyName.isNotEmpty) {
      return (name: allergyMatch!.group(1)!.trim(), dosage: '—');
    }
    return (name: 'Medication', dosage: '—');
  }

  String _explanationText(String message) {
    if (message.trim().isEmpty) {
      return 'These medications may interact. Please consult your doctor before taking them together.';
    }
    final lines = message.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length == 1) return lines.first;
    return lines.join('\n\n');
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
    final firstMed = _medAt(0, message);
    final secondMed = _medAt(1, message);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.navy),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Alerts and Warnings', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textDark)),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
              ),
              onPressed: alert == null ? null : () => _markRead(context, alert),
              child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppColors.textDark)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _tabLabel('All', false),
                _tabLabel('Drug Conflicts', true),
                _tabLabel('Checkup', false),
              ],
            ),
          ),
        ),
      ),
      body: _loadingMeds
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 80, color: AppColors.errorRed),
                        const SizedBox(height: 16),
                        const Text(
                          'Drug Conflict Detected',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'These medications in your list may interact dangerously',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: AppColors.textGrey, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Conflicting Medications',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.navy),
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
                          ),
                          child: Column(
                            children: [
                              _medicationRow(
                                name: firstMed.name,
                                dosage: firstMed.dosage,
                                iconBg: const Color(0xFFE0F7F7),
                                iconColor: AppColors.primaryTeal,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFEBEE),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.swap_vert, color: AppColors.errorRed, size: 22),
                              ),
                              const SizedBox(height: 8),
                              _medicationRow(
                                name: secondMed.name,
                                dosage: secondMed.dosage,
                                iconBg: const Color(0xFFFFF3E0),
                                iconColor: const Color(0xFFFF9800),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.errorRed,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            'Risk Level: HIGH',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: () => setState(() => _expanded = !_expanded),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE8E8E8)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'What does this mean?',
                                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textDark),
                                        ),
                                      ),
                                      Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textGrey),
                                    ],
                                  ),
                                  if (_expanded) ...[
                                    const SizedBox(height: 12),
                                    Text(
                                      _explanationText(message),
                                      style: const TextStyle(color: AppColors.textGrey, fontSize: 14, height: 1.5),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          detectedAt.isNotEmpty ? 'Detected: $detectedAt' : 'Detected: —',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: alert == null ? null : () => _markRead(context, alert),
                          child: const Text('Mark as Read', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                          child: const Text('Book Doctor Appointment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _tabLabel(String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: active ? AppColors.navy : AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: active ? AppColors.primaryTeal : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicationRow({
    required String name,
    required String dosage,
    required Color iconBg,
    required Color iconColor,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: iconBg,
          child: Icon(Icons.medication_liquid, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.textDark)),
              const SizedBox(height: 2),
              Text(dosage, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
