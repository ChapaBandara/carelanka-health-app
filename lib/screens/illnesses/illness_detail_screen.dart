import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class IllnessDetailScreen extends StatelessWidget {
  const IllnessDetailScreen({super.key});

  Widget _scaffold(
    BuildContext context, {
    required String name,
    required String since,
    required String initials,
    required String notes,
    required Widget medicationsSection,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Illness Detail'),
        centerTitle: true,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: CareLankaGradients.fab),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.addMedication),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFFB2DFDB),
                        child: Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            if (since.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(since, style: const TextStyle(color: AppColors.textGrey)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(notes, style: const TextStyle(height: 1.45)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Medications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                TextButton(onPressed: () => Navigator.pushNamed(context, AppRoutes.addMedication), child: const Text('Add')),
              ],
            ),
            medicationsSection,
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reminder history', style: TextStyle(fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, AppRoutes.reminderHistory),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicationsSection(List<Map<String, dynamic>> meds) {
    if (meds.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.medication_outlined,
        title: 'No medications yet',
        subtitle: 'Add a medication to track doses and reminders for this illness.',
      );
    }
    return Column(
      children: meds.map((m) {
        final medName = m['name'] as String? ?? 'Medication';
        final dosage = m['dosage'] as String? ?? '';
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(medName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: dosage.isNotEmpty ? Text(dosage) : null,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final illness = args is Map<String, String> ? args : null;
    final illnessId = illness?['illnessId'];
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final name = illness?['name'] ?? 'Illness';
    final since = illness?['since'] ?? '';
    final initials = illness?['initials'] ?? (name.isNotEmpty ? name[0].toUpperCase() : '?');
    final notes = illness?['notes'] ?? '';

    if (illnessId == null || illnessId.isEmpty) {
      return _scaffold(
        context,
        name: name,
        since: since,
        initials: initials,
        notes: notes,
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
        var displayName = name;
        var displaySince = since;
        var displayInitials = initials;
        var displayNotes = notes;

        if (illnessSnap.hasData && illnessSnap.data!.exists) {
          final ui = IllnessService().illnessDocToUiMap(illnessSnap.data!.data()!, illnessId);
          displayName = ui['name'] ?? displayName;
          displaySince = ui['since'] ?? displaySince;
          displayInitials = ui['initials'] ?? displayInitials;
          displayNotes = ui['notes'] ?? displayNotes;
        }

        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: MedicationService().watchMedicationsForIllness(userId: userId, illnessId: illnessId),
          builder: (context, medSnap) {
            final meds = medSnap.data ?? [];
            return _scaffold(
              context,
              name: displayName,
              since: displaySince,
              initials: displayInitials,
              notes: displayNotes,
              medicationsSection: _medicationsSection(meds),
            );
          },
        );
      },
    );
  }
}
