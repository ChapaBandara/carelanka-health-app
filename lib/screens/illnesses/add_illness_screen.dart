import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddIllnessScreen extends StatefulWidget {
  const AddIllnessScreen({super.key});

  @override
  State<AddIllnessScreen> createState() => _AddIllnessScreenState();
}

class _AddIllnessScreenState extends State<AddIllnessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _doctor = TextEditingController();
  final _notes = TextEditingController();
  final _since = TextEditingController();
  DateTime? _start;
  bool _isLongTerm = true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _doctor.dispose();
    _notes.dispose();
    _since.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final illnessId = await IllnessService().addIllness(
        userId: FirebaseAuth.instance.currentUser!.uid,
        illnessName: _name.text.trim(),
        diagnosedDate: _start!,
        doctorName: _doctor.text.trim().isEmpty ? null : _doctor.text.trim(),
        durationType: _isLongTerm ? 'long_term' : 'short_term',
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.addMedication,
        arguments: {
          'illnessId': illnessId,
          'illnessName': _name.text.trim(),
        },
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          'Add Illness',
          style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 18),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'What condition are you managing?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryTeal,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add the illness or condition first, then add medications inside it.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 24),
                LabeledIconField(
                  label: 'Illness / Condition',
                  hint: 'e.g. Hypertension, Diabetes, Fever',
                  controller: _name,
                  prefixIcon: Icons.favorite_border,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Diagnosed / Started On',
                  hint: 'Select Date',
                  readOnly: true,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now(),
                      initialDate: DateTime.now().subtract(const Duration(days: 30)),
                    );
                    if (d != null) {
                      setState(() {
                        _start = d;
                        _since.text = '${d.day}/${d.month}/${d.year}';
                      });
                    }
                  },
                  controller: _since,
                  suffix: const Icon(Icons.calendar_today_outlined, color: AppColors.textGrey, size: 22),
                  validator: (_) => _start == null ? 'Select a date' : null,
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Diagnosing Doctor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                    Text(
                      'Optional',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _doctor,
                  style: const TextStyle(fontSize: 15, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: 'e.g. Dr. Perera',
                    hintStyle: TextStyle(color: AppColors.textGrey.withValues(alpha: 0.85)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Duration',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 10),
                _durationToggle(),
                if (_isLongTerm) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primaryTeal, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This is an ongoing condition and will require continuous management.',
                            style: TextStyle(color: Colors.teal.shade800, fontSize: 13, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Additional Notes',
                  hint: 'Any notes about this condition...',
                  controller: _notes,
                  maxLines: 4,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : 'Continue to Add Medications',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationToggle() {
    return Row(
      children: [
        Expanded(
          child: _durationOption(
            label: 'Short-term',
            icon: Icons.access_time,
            selected: !_isLongTerm,
            onTap: () => setState(() => _isLongTerm = false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _durationOption(
            label: 'Long-term',
            icon: Icons.all_inclusive,
            selected: _isLongTerm,
            onTap: () => setState(() => _isLongTerm = true),
          ),
        ),
      ],
    );
  }

  Widget _durationOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0xFFE0F7F7) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primaryTeal : const Color(0xFFDEE2E6),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primaryTeal.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.navy : AppColors.textGrey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.navy : AppColors.textGrey,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
