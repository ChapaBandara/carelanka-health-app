import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #38 / #39 — Add Health Record form with optional document attach.
class AddHealthRecordScreen extends StatefulWidget {
  const AddHealthRecordScreen({super.key});

  @override
  State<AddHealthRecordScreen> createState() => _AddHealthRecordScreenState();
}

class _AddHealthRecordScreenState extends State<AddHealthRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _doctorHospital = TextEditingController();
  final _diagnosis = TextEditingController();
  final _notes = TextEditingController();
  final _dateDisplay = TextEditingController();
  DateTime? _date;
  String _type = 'Lab Report';
  bool _saving = false;

  @override
  void dispose() {
    _doctorHospital.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    _dateDisplay.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final parts = _doctorHospital.text.trim().split(',');
      final doctor = parts.isNotEmpty ? parts.first.trim() : _doctorHospital.text.trim();
      final hospital = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

      await HealthRecordService().addRecord(
        userId: FirebaseAuth.instance.currentUser!.uid,
        visitDate: _date!,
        doctorName: doctor,
        hospital: hospital.isEmpty ? doctor : hospital,
        diagnosis: _diagnosis.text.trim(),
        notes: _notes.text.trim(),
        documentType: _type,
      );
      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: 'Health record saved',
        subtitle: 'Your record has been saved to the library and linked to your timeline.',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _fieldDecoration({String? hint, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
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
      suffixIcon: suffix,
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Add Health Record', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEEEEEE)),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _label('Visit Date'),
                TextFormField(
                  readOnly: true,
                  controller: _dateDisplay,
                  decoration: _fieldDecoration(
                    hint: 'Select date',
                    suffix: const Icon(Icons.calendar_today_outlined, color: AppColors.textGrey, size: 20),
                  ),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: _date ?? DateTime.now(),
                    );
                    if (d != null) {
                      setState(() {
                        _date = d;
                        _dateDisplay.text = DateFormat('MMM d, yyyy').format(d);
                      });
                    }
                  },
                  validator: (_) => _date == null ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                _label('Doctor / Hospital'),
                TextFormField(
                  controller: _doctorHospital,
                  maxLines: 2,
                  decoration: _fieldDecoration(hint: 'e.g. Dr. Perera, Colombo General Hospital'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                _label('Diagnosis'),
                TextFormField(
                  controller: _diagnosis,
                  maxLines: 3,
                  decoration: _fieldDecoration(hint: 'Enter diagnosis or reason for visit...'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                _label('Notes'),
                TextFormField(
                  controller: _notes,
                  maxLines: 4,
                  decoration: _fieldDecoration(hint: "Add any doctor's instructions or personal notes..."),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Attach Document (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.navy, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text('Document Type', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: _fieldDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'Prescription', child: Text('Prescription')),
                    DropdownMenuItem(value: 'Lab Report', child: Text('Lab Report')),
                    DropdownMenuItem(value: 'Scan Report', child: Text('Scan Report')),
                    DropdownMenuItem(value: 'X-Ray', child: Text('X-Ray')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_outlined, color: AppColors.primaryTeal, size: 28),
                          SizedBox(height: 4),
                          Text('CBC.pdf', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 88,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F0FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFD1C4E9), style: BorderStyle.solid),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_upload_outlined, color: AppColors.navy, size: 28),
                            SizedBox(height: 4),
                            Text('Tap to upload', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : 'Save Record',
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
