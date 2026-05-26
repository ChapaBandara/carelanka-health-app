import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/medication_service.dart';
import 'package:carelanka_app/services/notification_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _freq = TextEditingController();
  final _times = TextEditingController();
  final _illness = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _freq.dispose();
    _times.dispose();
    _illness.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final medService = MedicationService();
    try {
      var illnessId = await medService.findIllnessIdByName(userId, _illness.text.trim());
      if (illnessId == null) {
        throw Exception('No illness found with that name. Add the illness first.');
      }
      final times = _times.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
      final medicationId = await medService.addMedication(
        userId: userId,
        illnessId: illnessId,
        name: _name.text.trim(),
        dosage: _dose.text.trim(),
        frequency: _freq.text.trim(),
        scheduledTimes: times,
      );
      await NotificationService.instance.scheduleMedicationReminders(
        medicationId: medicationId,
        title: '${_name.text.trim()} ${_dose.text.trim()}',
        timeStrings: times,
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Medication saved successfully');
      await showCareLankaSuccessNotification(
        context,
        title: 'Medication saved',
        subtitle: 'Amoxicillin 500mg has been added to your list. Reminders will follow your schedule.',
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
        title: const Text('Add / Edit Medication'),
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
                  label: 'Linked illness',
                  hint: 'e.g. Hypertension',
                  controller: _illness,
                  prefixIcon: Icons.healing_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Medicine name',
                  hint: 'e.g. Amoxicillin',
                  controller: _name,
                  prefixIcon: Icons.medication_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Dosage',
                  hint: 'e.g. 500mg',
                  controller: _dose,
                  prefixIcon: Icons.scale_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Frequency',
                  hint: 'e.g. Twice daily',
                  controller: _freq,
                  prefixIcon: Icons.repeat,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Reminder times',
                  hint: 'e.g. 8:00 AM, 8:00 PM',
                  controller: _times,
                  prefixIcon: Icons.schedule,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Save Medication', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
