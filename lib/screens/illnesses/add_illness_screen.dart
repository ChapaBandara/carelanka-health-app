import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
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
  final _notes = TextEditingController();
  final _since = TextEditingController();
  DateTime? _start;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _since.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await IllnessService().addIllness(
        userId: FirebaseAuth.instance.currentUser!.uid,
        illnessName: _name.text.trim(),
        diagnosedDate: _start!,
        notes: _notes.text.trim(),
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Illness saved successfully');
      await showCareLankaSuccessNotification(
        context,
        title: 'Illness profile created',
        subtitle: 'You can now attach medications and reminders to this condition.',
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
        title: const Text('Add Illness'),
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
                  label: 'Condition name',
                  hint: 'e.g. Hypertension',
                  controller: _name,
                  prefixIcon: Icons.healing_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Diagnosed / Start date',
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
                  prefixIcon: Icons.calendar_today_outlined,
                  validator: (_) => _start == null ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Notes for your doctor',
                  controller: _notes,
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Save Illness', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
