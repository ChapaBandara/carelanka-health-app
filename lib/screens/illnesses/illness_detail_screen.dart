import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
        name: illness?['name'] ?? 'Illness',
        diagnosedLabel: illness?['since'] ?? '',
        endsLabel: '',
        durationBadge: 'Long-term',
        showRenewalAlert: false,
        medicationsSection: const EmptyListPlaceholder(
          icon: Icons.medication_outlined,
          title: 'No medications yet',
          subtitle: 'Add a medication to track doses and reminders for this illness.',
        ),
        illnessId: '',
      );
    }

    return StreamBuilder(
      stream: IllnessService().watchIllness(illnessId),
      builder: (context, illnessSnap) {
        var displayName = illness?['name'] ?? 'Illness';
        var diagnosedLabel = illness?['since'] ?? '';
        var endsLabel = '';
        var durationBadge = 'Long-term';
        var illnessStatus = illness?['status'] ?? 'active';

        if (illnessSnap.hasData && illnessSnap.data!.exists) {
          final ui = IllnessService().illnessDocToUiMap(illnessSnap.data!.data()!, illnessId);
          displayName = ui['name'] ?? displayName;
          diagnosedLabel = ui['diagnosedLabel'] ?? ui['since'] ?? diagnosedLabel;
          endsLabel = ui['endsLabel'] ?? '';
          durationBadge = ui['durationBadge'] ?? durationBadge;
          illnessStatus = ui['status'] ?? illnessStatus;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: MedicationService().watchMedicationsForIllness(userId: userId, illnessId: illnessId),
          builder: (context, medSnap) {
            final meds = medSnap.data ?? [];
            final showRenewalAlert = meds.any(_isLowStock);

            return _buildScaffold(
              context,
              name: displayName,
              diagnosedLabel: diagnosedLabel,
              endsLabel: endsLabel,
              durationBadge: durationBadge,
              showRenewalAlert: showRenewalAlert,
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
                      children: meds.map((m) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _medicationCard(context, m, illnessId: illnessId, illnessName: displayName),
                          )).toList(),
                    ),
            );
          },
        );
      },
    );
  }

  bool _isLowStock(Map<String, dynamic> med) {
    final stock = (med['stockCount'] as num?)?.toInt() ?? 0;
    final threshold = (med['lowStockThreshold'] as num?)?.toInt() ?? 5;
    return stock <= threshold;
  }

  Widget _buildScaffold(
    BuildContext context, {
    required String name,
    required String diagnosedLabel,
    required String endsLabel,
    required String durationBadge,
    required bool showRenewalAlert,
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
              endsLabel: endsLabel,
              durationBadge: durationBadge,
              showRenewalAlert: showRenewalAlert,
              onBookAppointment: () => Navigator.pushNamed(context, AppRoutes.addAppointment),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Prescribed Medications',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.navy),
                ),
                if (illnessId.isNotEmpty)
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
                      'Add',
                      style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            medicationsSection,
            const SizedBox(height: 20),
            _actionButton(
              label: 'Mark All Taken Today',
              background: const Color(0xFFE3F2FD),
              foreground: const Color(0xFF1565C0),
              onTap: () {},
            ),
            const SizedBox(height: 10),
            _actionButton(
              label: 'View Reminder History',
              background: const Color(0xFFE0F7F7),
              foreground: AppColors.primaryTeal,
              onTap: () => Navigator.pushNamed(context, AppRoutes.reminderHistory),
            ),
            if (!isCompleted) ...[
              const SizedBox(height: 10),
              _actionButton(
                label: 'End This Illness',
                background: Colors.white,
                foreground: AppColors.errorRed,
                borderColor: AppColors.errorRed,
                onTap: () => _endIllness(context, illnessId: illnessId, name: name),
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
    required String endsLabel,
    required String durationBadge,
    required bool showRenewalAlert,
    required VoidCallback onBookAppointment,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (diagnosedLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(diagnosedLabel, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                    if (endsLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(endsLabel, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                    ],
                    if (showRenewalAlert) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4FC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Medications running low. Consider visiting your doctor for renewal.',
                              style: TextStyle(color: AppColors.navy, fontSize: 13, height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 36,
                              child: ElevatedButton(
                                onPressed: onBookAppointment,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF42A5F5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: const Text('Book Appointment', style: TextStyle(fontWeight: FontWeight.w600)),
                              ),
                            ),
                          ],
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
    final mealTiming = _formatMealTiming(med['mealTiming'] as String? ?? '');
    final times = (med['scheduledTimes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final stock = (med['stockCount'] as num?)?.toInt() ?? 0;
    final low = _isLowStock(med);

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
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.navy)),
                          if (dosage.isNotEmpty)
                            Text(dosage, style: const TextStyle(color: AppColors.textGrey, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(
                            [frequency, mealTiming].where((s) => s.isNotEmpty).join(' • '),
                            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
                          ),
                          if (times.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: times
                                  .map(
                                    (t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE0F7F7),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        t,
                                        style: const TextStyle(
                                          color: AppColors.primaryTeal,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_horiz, color: AppColors.textGrey),
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
                        if (low) ...[
                          Text(
                            '$stock tablets left',
                            style: const TextStyle(color: AppColors.errorRed, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.errorRed,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Running Low!',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _endIllness(
    BuildContext context, {
    required String illnessId,
    required String name,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End this illness?'),
        content: Text(
          'Mark "$name" as completed? It will move to your Completed Illnesses list.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            child: const Text('End illness'),
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

  String _formatMealTiming(String value) {
    switch (value.toLowerCase()) {
      case 'before_meals':
        return 'Before food';
      case 'after_meals':
        return 'After food';
      case 'with_meals':
        return 'With food';
      default:
        if (value.isEmpty || value == 'anytime') return 'Anytime';
        return value;
    }
  }

  Widget _actionButton({
    required String label,
    required Color background,
    required Color foreground,
    Color? borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null ? Border.all(color: borderColor) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
