import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/adherence_service.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #21 / #23 — Illness detail with medications, complete & delete actions.
class IllnessDetailScreen extends StatelessWidget {
  const IllnessDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final illness = args is Map<String, String> ? args : null;
    final illnessId = illness?['illnessId'];
    final userId = FirebaseAuth.instance.currentUser!.uid;

    if (illnessId == null || illnessId.isEmpty) {
      return _buildScaffold(
        context,
        userId: userId,
        name: illness?['name'] ?? 'Illness',
        diagnosedLabel: illness?['since'] ?? '',
        doctorName: '',
        notes: '',
        durationBadge: 'LONG-TERM',
        illnessId: '',
        illnessStatus: 'active',
        medicationsSection: const EmptyListPlaceholder(
          icon: Icons.medication_outlined,
          title: 'No medications yet',
          subtitle: 'Add a medication to track doses and reminders for this illness.',
        ),
      );
    }

    return StreamBuilder(
      stream: IllnessService().watchIllness(illnessId),
      builder: (context, illnessSnap) {
        var displayName = illness?['name'] ?? 'Illness';
        var diagnosedLabel = illness?['since'] ?? '';
        var durationBadge = 'LONG-TERM';
        var illnessStatus = illness?['status'] ?? 'active';
        var doctorName = '';
        var notes = '';

        if (illnessSnap.hasData && illnessSnap.data!.exists) {
          final ui = IllnessService().illnessDocToUiMap(illnessSnap.data!.data()!, illnessId);
          displayName = ui['name'] ?? displayName;
          diagnosedLabel = ui['diagnosedLabel'] ?? ui['since'] ?? diagnosedLabel;
          durationBadge = (ui['durationBadge'] ?? 'Long-term').toUpperCase();
          illnessStatus = ui['status'] ?? illnessStatus;
          doctorName = ui['doctorName'] ?? '';
          notes = ui['notes'] ?? '';
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: MedicationService().watchMedicationsForIllness(userId: userId, illnessId: illnessId),
          builder: (context, medSnap) {
            final meds = medSnap.data ?? [];

            return _buildScaffold(
              context,
              userId: userId,
              name: displayName,
              diagnosedLabel: diagnosedLabel,
              doctorName: doctorName,
              notes: notes,
              durationBadge: durationBadge,
              illnessId: illnessId,
              illnessName: displayName,
              illnessStatus: illnessStatus,
              medicationsSection: meds.isEmpty
                  ? const EmptyListPlaceholder(
                      icon: Icons.medication_outlined,
                      title: 'No medications yet',
                      subtitle: 'Add a medication to track doses and reminders for this illness.',
                    )
                  : Column(
                      children: meds
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Dismissible(
                                key: ValueKey(m['medicationId'] ?? m['id'] ?? ''),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 24),
                                  decoration: BoxDecoration(
                                    color: AppColors.errorRed,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                ),
                                confirmDismiss: (_) async {
                                  final result = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete medication?'),
                                      content: Text(
                                        'Delete ${m['name'] ?? 'this medication'}? '
                                        'This cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return result ?? false;
                                },
                                onDismissed: (_) async {
                                  final id = m['medicationId'] ?? m['id'] ?? '';
                                  if (id.isEmpty) return;
                                  try {
                                    await MedicationService().deleteMedication(id);
                                  } catch (e) {
                                    if (context.mounted) {
                                      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
                                    }
                                  }
                                },
                                child: _medicationCard(
                                  context,
                                  m,
                                  illnessId: illnessId,
                                  illnessName: displayName,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required String userId,
    required String name,
    required String diagnosedLabel,
    required String doctorName,
    required String notes,
    required String durationBadge,
    required String illnessId,
    String? illnessName,
    String illnessStatus = 'active',
    required Widget medicationsSection,
  }) {
    final isCompleted = illnessStatus == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.navy),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          name,
          style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_vert, color: AppColors.navy),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _summaryCard(
              name: name,
              diagnosedLabel: diagnosedLabel,
              doctorName: doctorName,
              notes: notes,
              durationBadge: durationBadge,
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Medications',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                if (illnessId.isNotEmpty && !isCompleted)
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.addMedication,
                      arguments: {
                        'illnessId': illnessId,
                        'illnessName': illnessName ?? name,
                      },
                    ),
                    icon: const Icon(Icons.add, size: 18, color: AppColors.primaryTeal),
                    label: const Text(
                      'Add New',
                      style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            medicationsSection,
            if (illnessId.isNotEmpty && !isCompleted) ...[
              const SizedBox(height: 24),
              GradientPrimaryButton(
                label: 'Mark as Completed',
                onPressed: () => _completeIllness(context, illnessId: illnessId, name: name),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _deleteRecord(context, userId: userId, illnessId: illnessId, name: name),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorRed,
                  side: const BorderSide(color: AppColors.errorRed, width: 1.5),
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Delete Record', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard({
    required String name,
    required String diagnosedLabel,
    required String doctorName,
    required String notes,
    required String durationBadge,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                color: AppColors.primaryTeal,
                borderRadius: BorderRadius.horizontal(left: Radius.circular(14)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.navy),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F7F7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            durationBadge,
                            style: const TextStyle(
                              color: AppColors.navy,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (diagnosedLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(diagnosedLabel, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                    if (doctorName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(doctorName, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        notes,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationCard(
    BuildContext context,
    Map<String, dynamic> med, {
    required String illnessId,
    required String illnessName,
  }) {
    final name = med['name'] as String? ?? 'Medication';
    final dosage = med['dosage'] as String? ?? '';
    final frequency = med['frequency'] as String? ?? '';
    final times = (med['scheduledTimes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final instruction = [dosage, frequency].where((s) => s.isNotEmpty).join(', ');

    // Stock fields — only present when the user filled in stock details.
    final stockCount = med['stockCount'] as int?;
    final lowStockThreshold = med['lowStockThreshold'] as int? ?? 0;

    // Compute days remaining when stock data is available.
    int? daysRemaining;
    bool stockLow = false;
    if (stockCount != null) {
      final adherence = AdherenceService();
      final doseCount = _doseCountForFrequency(frequency);
      daysRemaining = adherence.calculateStockDaysRemaining(stockCount, doseCount);
      stockLow = lowStockThreshold > 0 &&
          adherence.isStockLow(stockCount, doseCount, lowStockThreshold);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(color: Color(0xFFE0F7F7), shape: BoxShape.circle),
              child: const Icon(Icons.medication_outlined, color: AppColors.primaryTeal, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                  if (instruction.isNotEmpty)
                    Text(instruction, style: const TextStyle(color: AppColors.textGrey, fontSize: 13, height: 1.35)),
                  if (times.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: times
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7F7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time, size: 14, color: AppColors.primaryTeal),
                                  const SizedBox(width: 4),
                                  Text(
                                    t,
                                    style: const TextStyle(
                                      color: AppColors.primaryTeal,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  // ── Stock status row ──────────────────────────────────
                  if (daysRemaining != null) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 13,
                              color: _stockDayColor(daysRemaining),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$daysRemaining day${daysRemaining == 1 ? '' : 's'} left',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _stockDayColor(daysRemaining),
                              ),
                            ),
                          ],
                        ),
                        if (stockLow)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              'Running Low!',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.errorRed,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textGrey, size: 20),
              onSelected: (value) {
                if (value == 'edit') {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.addMedication,
                    arguments: {
                      'illnessId': illnessId,
                      'illnessName': illnessName,
                      'medication': med,
                    },
                  );
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns the colour for the stock days-remaining label.
  Color _stockDayColor(int days) {
    if (days <= 3) return AppColors.errorRed;
    if (days <= 7) return AppColors.warningAmber;
    return AppColors.successGreen;
  }

  /// Converts a frequency label to a numeric doses-per-day count.
  int _doseCountForFrequency(String frequency) {
    switch (frequency) {
      case 'Once daily':
        return 1;
      case 'Three times daily':
        return 3;
      case 'Four times daily':
        return 4;
      default:
        return 2;
    }
  }

  Future<void> _completeIllness(
    BuildContext context, {
    required String illnessId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as completed?'),
        content: Text('Move "$name" to your Completed Illnesses list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await IllnessService().completeIllness(illnessId);
      if (!context.mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Illness completed',
        subtitle: '$name has been moved to Completed Illnesses.',
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }

  Future<void> _deleteRecord(
    BuildContext context, {
    required String userId,
    required String illnessId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete illness record?'),
        content: Text(
          'Delete "$name" and all medications linked to it? This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await IllnessService().deleteIllness(userId: userId, illnessId: illnessId);
      if (!context.mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Record deleted',
        subtitle: '$name and its medications were removed.',
      );
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      if (!context.mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }
}
