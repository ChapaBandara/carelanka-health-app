import 'dart:io';

import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/checkup_service.dart';
import 'package:carelanka_app/services/health_record_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

/// CareLanka UI #38 / #39 — Add or edit health record with optional document attach.
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

  static const _validTypes = [
    'Prescription',
    'Lab Report',
    'Scan Report',
    'X-Ray',
    'Summary Report (Annual Checkup Report)',
  ];

  /// Normalise any stored document type to one of the four valid dropdown items.
  String _normaliseType(String? raw) {
    if (raw == null || raw.isEmpty) return 'Lab Report';
    final lower = raw.toLowerCase();
    if (lower.contains('prescription')) return 'Prescription';
    if (lower.contains('summary') || lower.contains('annual') || lower.contains('checkup')) {
      return 'Summary Report (Annual Checkup Report)';
    }
    if (lower.contains('lab') || lower.contains('report') || lower.contains('test')) return 'Lab Report';
    if (lower.contains('scan') || lower.contains('mri') || lower.contains('ct')) return 'Scan Report';
    if (lower.contains('x-ray') || lower.contains('xray') || lower.contains('x ray')) return 'X-Ray';
    // If it already exactly matches a valid type, keep it
    if (_validTypes.contains(raw)) return raw;
    // Default fallback
    return 'Lab Report';
  }
  File? _pickedFile;
  String? _existingDocumentUrl;
  String? _editRecordId;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadEditArgs());
  }

  void _loadEditArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is! Map<String, String>) return;

    final millis = int.tryParse(args['visitDateMillis'] ?? '');
    DateTime? visitDate;
    if (millis != null) {
      visitDate = DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      final parsed = DateFormat('MMM d, yyyy').tryParse(args['monthDay'] ?? '');
      visitDate = parsed;
    }

    final doctor = args['doctor'] ?? '';
    final hospital = args['place'] ?? '';
    final doctorHospital = hospital.isNotEmpty ? '$doctor, $hospital' : doctor;

    setState(() {
      _isEdit = true;
      _editRecordId = args['recordId'];
      _date = visitDate;
      if (visitDate != null) {
        _dateDisplay.text = DateFormat('MMM d, yyyy').format(visitDate);
      }
      _doctorHospital.text = doctorHospital;
      _diagnosis.text = args['diagnosis'] ?? '';
      _notes.text = args['notes'] ?? '';
      _type = _normaliseType(args['documentType'] ?? args['tag']);
      _existingDocumentUrl = args['documentUrl'];
    });
  }

  @override
  void dispose() {
    _doctorHospital.dispose();
    _diagnosis.dispose();
    _notes.dispose();
    _dateDisplay.dispose();
    super.dispose();
  }

  void _clearAttachment() {
    setState(() {
      _pickedFile = null;
      _existingDocumentUrl = null;
    });
  }

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      final parts = _doctorHospital.text.trim().split(',');
      final doctor = parts.isNotEmpty ? parts.first.trim() : _doctorHospital.text.trim();
      final hospital = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

      if (_isEdit && _editRecordId != null) {
        await HealthRecordService().updateRecord(
          recordId: _editRecordId!,
          userId: userId,
          visitDate: _date!,
          doctorName: doctor,
          hospital: hospital.isEmpty ? doctor : hospital,
          diagnosis: _diagnosis.text.trim(),
          notes: _notes.text.trim(),
          documentType: _type,
          documentFile: _pickedFile,
          existingDocumentUrl: _existingDocumentUrl,
        );
      } else {
        await HealthRecordService().addRecord(
          userId: userId,
          visitDate: _date!,
          doctorName: doctor,
          hospital: hospital.isEmpty ? doctor : hospital,
          diagnosis: _diagnosis.text.trim(),
          notes: _notes.text.trim(),
          documentType: _type,
          documentFile: _pickedFile,
        );
      }

      await CheckupService().evaluateForUser(userId);

      if (!mounted) return;
      await showCareLankaSuccessNotification(
        context,
        title: _isEdit ? 'Health record updated' : 'Health record saved',
        subtitle: _isEdit
            ? 'Your changes have been saved.'
            : 'Your record has been saved to the library and linked to your timeline.',
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

  String get _attachmentLabel {
    if (_pickedFile != null) {
      return _pickedFile!.path.split('/').last;
    }
    if (_existingDocumentUrl != null && _existingDocumentUrl!.isNotEmpty) {
      final uri = Uri.tryParse(_existingDocumentUrl!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        return Uri.decodeComponent(uri.pathSegments.last);
      }
      return 'Existing attachment';
    }
    return 'Tap to upload';
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
        title: Text(
          _isEdit ? 'Edit Health Record' : 'Add Health Record',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
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
                  key: ValueKey(_type),
                  isExpanded: true,
                  initialValue: _type,
                  decoration: _fieldDecoration(),
                  items: const [
                    DropdownMenuItem(value: 'Prescription', child: Text('Prescription', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Lab Report', child: Text('Lab Report', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Scan Report', child: Text('Scan Report', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'X-Ray', child: Text('X-Ray', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(
                      value: 'Summary Report (Annual Checkup Report)',
                      child: Text(
                        'Summary Report (Annual Checkup Report)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (_pickedFile != null || (_existingDocumentUrl?.isNotEmpty ?? false))
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFDEE2E6)),
                            ),
                            child: _pickedFile != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Image.file(_pickedFile!, fit: BoxFit.cover),
                                  )
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.insert_drive_file_outlined, color: AppColors.primaryTeal, size: 28),
                                      SizedBox(height: 4),
                                      Text('File', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: Material(
                              color: AppColors.errorRed,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _clearAttachment,
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.close, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_pickedFile != null || (_existingDocumentUrl?.isNotEmpty ?? false))
                      const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDocument,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 88,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F0FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD1C4E9)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: AppColors.navy, size: 28),
                              const SizedBox(height: 4),
                              Text(
                                _attachmentLabel,
                                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(
                  label: _saving ? 'Saving...' : (_isEdit ? 'Update Record' : 'Save Record'),
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
