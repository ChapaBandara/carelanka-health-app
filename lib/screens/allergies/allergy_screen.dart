import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/allergy_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:carelanka_app/widgets/empty_list_placeholder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AllergyScreen extends StatelessWidget {
  const AllergyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<List<Map<String, String>>>(
      stream: AllergyService().watchAllergyMaps(userId),
      builder: (context, snapshot) {
        final allergies = snapshot.data ?? [];

        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Allergy Profile'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const AddAllergyScreen())),
        backgroundColor: AppColors.navy,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add allergy', style: TextStyle(color: Colors.white)),
      ),
      body: allergies.isEmpty
          ? const EmptyListPlaceholder(
              icon: Icons.coronavirus_outlined,
              title: 'No allergies recorded',
              subtitle: 'Add allergens so caregivers and doctors can see them on your profile.',
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allergies.length,
              itemBuilder: (_, i) {
                final a = allergies[i];
                return _allergyTile(
                  a['name'] ?? '',
                  a['severity'] ?? '',
                  a['category'] ?? '',
                  _iconForCategory(a['category'] ?? ''),
                );
              },
            ),
    );
      },
    );
  }

  IconData _iconForCategory(String cat) {
    final c = cat.toLowerCase();
    if (c.contains('food')) return Icons.restaurant_outlined;
    if (c.contains('environment')) return Icons.air;
    return Icons.medication_outlined;
  }

  Widget _allergyTile(String name, String sev, String cat, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFFFFEBEE), child: Icon(icon, color: AppColors.errorRed)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('$cat • $sev reaction'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class AddAllergyScreen extends StatefulWidget {
  const AddAllergyScreen({super.key});

  @override
  State<AddAllergyScreen> createState() => _AddAllergyScreenState();
}

class _AddAllergyScreenState extends State<AddAllergyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  String _severity = 'Moderate';
  String _category = 'Drug class';

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await AllergyService().addAllergy(
        userId: FirebaseAuth.instance.currentUser!.uid,
        allergyName: _name.text.trim(),
        severity: _severity,
        category: _category,
        notes: _note.text.trim(),
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Allergy saved successfully');
      await showCareLankaSuccessNotification(
        context,
        title: 'Allergy saved',
        subtitle: 'Your allergy profile has been updated. Caregivers you link will see this information.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Add Allergy'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LabeledIconField(
                  label: 'Allergen name',
                  hint: 'e.g. Penicillin',
                  controller: _name,
                  prefixIcon: Icons.warning_amber_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                const Text('Category', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Drug class', child: Text('Drug class')),
                    DropdownMenuItem(value: 'Food', child: Text('Food')),
                    DropdownMenuItem(value: 'Environmental', child: Text('Environmental')),
                  ],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 18),
                const Text('Severity', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Mild', label: Text('Mild')),
                    ButtonSegment(value: 'Moderate', label: Text('Moderate')),
                    ButtonSegment(value: 'Severe', label: Text('Severe')),
                  ],
                  selected: {_severity},
                  onSelectionChanged: (s) => setState(() => _severity = s.first),
                ),
                const SizedBox(height: 18),
                LabeledIconField(label: 'Notes', controller: _note, prefixIcon: Icons.notes_outlined, maxLines: 3),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Save allergy', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
