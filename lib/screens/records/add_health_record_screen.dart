import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddHealthRecordScreen extends StatefulWidget {
  const AddHealthRecordScreen({super.key});

  @override
  State<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends State<AddHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _doctor = TextEditingController();
  final _place = TextEditingController();
  final _notes = TextEditingController();
  final _dateDisplay = TextEditingController();
  DateTime? _date;
  String _type = 'Visit summary';

  @override
  void dispose() {
    _title.dispose();
    _doctor.dispose();
    _place.dispose();
    _notes.dispose();
    _dateDisplay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      await HealthRecordService().addRecord(
        userId: FirebaseAuth.instance.currentUser!.uid,
        visitDate: _date!,
        doctorName: _doctor.text.trim(),
        hospital: _place.text.trim(),
        diagnosis: _title.text.trim(),
        notes: _notes.text.trim(),
        documentType: _type,
      );
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Health record saved successfully');
      await showCareLankaSuccessNotification(
        context,
        title: 'Health record added',
        subtitle: 'Your record has been saved to the library and linked to your timeline.',
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
        title: const Text('Add Health Record'),
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
                const Text('Record type', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Visit summary', child: Text('Visit summary')),
                    DropdownMenuItem(value: 'Prescription', child: Text('Prescription')),
                    DropdownMenuItem(value: 'Lab report', child: Text('Lab report')),
                    DropdownMenuItem(value: 'Scan / Imaging', child: Text('Scan / Imaging')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Title',
                  hint: 'e.g. Annual checkup',
                  controller: _title,
                  prefixIcon: Icons.title,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Doctor',
                  hint: 'Dr. Perera',
                  controller: _doctor,
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Facility',
                  hint: 'Hospital or clinic',
                  controller: _place,
                  prefixIcon: Icons.local_hospital_outlined,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Date of visit',
                  readOnly: true,
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: DateTime.now(),
                    );
                    if (d != null) {
                      setState(() {
                        _date = d;
                        _dateDisplay.text = '${d.day}/${d.month}/${d.year}';
                      });
                    }
                  },
                  controller: _dateDisplay,
                  prefixIcon: Icons.calendar_today_outlined,
                  validator: (_) => _date == null ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Notes',
                  controller: _notes,
                  prefixIcon: Icons.notes_outlined,
                  maxLines: 4,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Save Record', onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
