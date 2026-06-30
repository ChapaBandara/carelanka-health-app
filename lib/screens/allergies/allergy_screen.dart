import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/allergy_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_success_sheet.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// CareLanka UI #53 — Allergy Profile screen.
class AllergyScreen extends StatelessWidget {
  const AllergyScreen({super.key});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'severe':
        return AppColors.errorRed;
      case 'moderate':
        return const Color(0xFFFF8A65);
      default:
        return AppColors.primaryTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeScopeId;

    return StreamBuilder<List<Map<String, String>>>(
      stream: AllergyService().watchAllergyMaps(userId),
      builder: (context, snapshot) {
        final allergies = snapshot.data ?? [];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
            title: const Text('Allergy Profile', style: TextStyle(fontWeight: FontWeight.w700)),
            centerTitle: true,
            actions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline)),
            ],
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: CareLankaGradients.fab),
            child: FloatingActionButton(
              elevation: 0,
              backgroundColor: Colors.transparent,
              onPressed: () => _openAddSheet(context),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
          body: allergies.isEmpty
              ? const EmptyListPlaceholder(
                  icon: Icons.coronavirus_outlined,
                  title: 'No allergies recorded',
                  subtitle: 'Add allergens so caregivers and doctors can see them on your profile.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF9C4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFFF176)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Color(0xFFF9A825), size: 22),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Your allergy profile is used to warn you of potentially dangerous medications. Keep this updated.',
                              style: TextStyle(color: Color(0xFF6D4C00), fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    for (final a in allergies) _allergyCard(context, userId, a),
                  ],
                ),
        );
      },
    );
      },
    );
  }

  Widget _allergyCard(BuildContext context, String userId, Map<String, String> a) {
    final name = a['name'] ?? '';
    final severity = a['severity'] ?? 'Moderate';
    final notes = a['notes'] ?? a['category'] ?? '';
    final color = _severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 12, height: 12, margin: const EdgeInsets.only(top: 4), decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppColors.textGrey),
                    children: [
                      TextSpan(text: '$severity - ', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                      TextSpan(text: notes.isEmpty ? 'No notes' : notes, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final id = a['allergyId'];
              if (id != null) await AllergyService().deleteAllergy(id);
            },
            icon: const Icon(Icons.delete_outline, color: AppColors.errorRed, size: 22),
          ),
        ],
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    final name = TextEditingController();
    final notes = TextEditingController();
    var severity = 'Moderate';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Padding(
              padding: EdgeInsets.only(
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom),
              child: SingleChildScrollView(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Add Allergy', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Allergy Name', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(controller: name, decoration: InputDecoration(hintText: 'E.g. Amoxicillin', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 14),
                      const Text('Severity', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: severity,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        items: const [
                          DropdownMenuItem(value: 'Mild', child: Text('Mild')),
                          DropdownMenuItem(value: 'Moderate', child: Text('Moderate')),
                          DropdownMenuItem(value: 'Severe', child: Text('Severe')),
                        ],
                        onChanged: (v) => setModal(() => severity = v ?? severity),
                      ),
                      const SizedBox(height: 14),
                      const Text('Notes (Optional)', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(controller: notes, maxLines: 3, decoration: InputDecoration(hintText: 'Add symptoms or reactions', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 20),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            if (name.text.trim().isEmpty) return;
                            try {
                              await AllergyService().addAllergy(
                                userId: context.activeScopeId,
                                allergyName: name.text.trim(),
                                severity: severity,
                                category: 'General',
                                notes: notes.text.trim(),
                              );
                              if (!context.mounted) return;
                              Navigator.pop(ctx);
                              await showCareLankaSuccessSheet(
                                context,
                                icon: Icons.check_rounded,
                                title: 'Allergy Saved!',
                                message: '${name.text.trim()} ($severity) has been added to your allergy profile.',
                                note: 'CareLanka will now warn you if any medication you add conflicts with this allergy.',
                              );
                            } catch (e) {
                              if (!context.mounted) return;
                              showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            height: 52,
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: CareLankaGradients.primaryHorizontal),
                            child: const Center(child: Text('Save Allergy', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
