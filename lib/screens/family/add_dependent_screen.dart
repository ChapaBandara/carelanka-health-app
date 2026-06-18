import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/constants/health_profile_options.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/date_helpers.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/widgets/carelanka/carelanka_success_sheet.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/profile_dropdown_field.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddDependentScreen extends StatefulWidget {
  const AddDependentScreen({super.key});

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _rel = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _dobDisplay = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String? _bloodType;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _dobDisplay.dispose();
    super.dispose();
  }

  String? _phoneLk(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return 'Enter 9 digits (e.g. 77 123 4567)';
    return null;
  }

  String? _requiredSelection(String? value, String label) {
    if (value == null || value.isEmpty) return '$label is required';
    return null;
  }

  Future<void> _save({bool createLogin = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final guardian = auth.profile?.fullName ?? 'Primary account';
    final ownerId = FirebaseAuth.instance.currentUser!.uid;

    try {
      await FamilyService().addDependentProfile(
        ownerId: ownerId,
        fullName: _name.text.trim(),
        relationship: _rel.text.trim().isEmpty ? 'Dependent' : _rel.text.trim(),
        dateOfBirth: _dob,
        gender: _gender,
        bloodType: _bloodType,
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      return;
    }

    if (createLogin) {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.register,
        arguments: {
          'isDependent': true,
          'guardianName': guardian,
          'prefillName': _name.text.trim(),
          'prefillEmail': _email.text.trim(),
          'prefillPhone': _phone.text.trim(),
          'prefillGender': _gender,
          'prefillBloodType': _bloodType,
          'prefillDob': _dob?.millisecondsSinceEpoch,
        },
      );
      return;
    }

    if (!mounted) return;
    final relationship = _rel.text.trim().isEmpty ? 'Dependent' : _rel.text.trim();
    await showCareLankaSuccessSheet(
      context,
      icon: Icons.person_add_alt_1_rounded,
      title: 'Family Member Added!',
      message: '${_name.text.trim()} has been added to your family health profile.',
      chipLabel: relationship,
      primaryLabel: 'Done',
      onPrimary: () => Navigator.pop(context),
      secondaryLabel: 'Back to Family',
      onSecondary: () => Navigator.pop(context),
    );
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
        title: const Text('Create Dependent'),
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
                  label: 'Full Name',
                  hint: 'e.g. Nimal Perera',
                  controller: _name,
                  validator: (v) => Validators.requiredField(v, 'Full Name'),
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rel,
                  decoration: const InputDecoration(
                    labelText: 'Relationship (e.g. Child)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Date of Birth',
                  hint: 'DD/MM/YYYY',
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(2010),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() {
                        _dob = picked;
                        _dobDisplay.text = DateHelpers.formatDmySlashes(picked);
                      });
                    }
                  },
                  validator: (_) => _dob == null ? 'Date of Birth is required' : null,
                  prefixIcon: Icons.calendar_today_outlined,
                  controller: _dobDisplay,
                ),
                const SizedBox(height: 16),
                ProfileDropdownField(
                  label: 'Gender',
                  hint: 'Select gender',
                  value: _gender,
                  items: HealthProfileOptions.genders,
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => _requiredSelection(v, 'Gender'),
                ),
                const SizedBox(height: 16),
                ProfileDropdownField(
                  label: 'Blood Type',
                  hint: 'Select blood type',
                  value: _bloodType,
                  items: HealthProfileOptions.bloodTypes,
                  onChanged: (v) => setState(() => _bloodType = v),
                  validator: (v) => _requiredSelection(v, 'Blood type'),
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Phone Number',
                  hint: '77 123 4567',
                  controller: _phone,
                  validator: _phoneLk,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Email',
                  hint: 'yourname@example.com',
                  controller: _email,
                  validator: Validators.email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Password',
                  controller: _password,
                  validator: Validators.password,
                  obscureText: _obscure1,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                    icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 16),
                LabeledIconField(
                  label: 'Confirm Password',
                  controller: _confirm,
                  validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  obscureText: _obscure2,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                    icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 24),
                GradientPrimaryButton(label: 'Create profile', onPressed: () => _save()),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _save(createLogin: true),
                  child: const Text('Create profile with app login (dependent)'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Dependent logins only see their family link; health data is managed by the primary account.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
