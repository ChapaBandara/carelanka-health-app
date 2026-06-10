import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/health_profile_options.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/auth_notifications.dart';
import 'package:carelanka_app/core/utils/date_helpers.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/core/utils/user_data_sync.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/user_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:carelanka_app/widgets/auth/logged_out_only_gate.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/profile_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final prefill = args['prefillName'] as String?;
        if (prefill != null) _name.text = prefill;
      }
    });
  }

  bool get _isDependentRegistration {
    final args = ModalRoute.of(context)?.settings.arguments;
    return args is Map && args['isDependent'] == true;
  }

  @override
  void dispose() {
    _name.dispose();
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    final isDependent = args is Map && args['isDependent'] == true;
    final guardianName = args is Map ? args['guardianName'] as String? : null;
    final authProvider = context.read<AuthProvider>();
    final data = context.read<UserDataProvider>();

    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );
      final uid = credential.user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'uid': uid,
        'fullName': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().replaceAll(RegExp(r'\D'), ''),
        if (_dob != null) 'dateOfBirth': Timestamp.fromDate(_dob!),
        'gender': _gender,
        'bloodType': _bloodType,
        'createdAt': Timestamp.fromDate(DateTime.now()),
        'adherenceScore': 0.0,
        'averageVisitGapDays': 30,
        'notificationPreferences': UserService.defaultNotificationPreferences(),
        if (isDependent) 'isDependent': true,
        if (guardianName != null) 'guardianName': guardianName,
      });
      if (!mounted) return;
      await showRegisterSuccessNotification(context);
      if (!mounted) return;
      await authProvider.loadFromFirebase();
      syncUserDataForProfile(data, authProvider.profile);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
    } catch (e) {
      if (!mounted) return;
      await showRegisterErrorNotification(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Create Account'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Let us get started',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your CareLanka account',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                LabeledIconField(
                  label: 'Full Name',
                  hint: 'e.g. Nimal Perera',
                  controller: _name,
                  validator: (v) => Validators.requiredField(v, 'Full Name'),
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Date of Birth',
                  hint: 'DD/MM/YYYY',
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
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
                const SizedBox(height: 18),
                ProfileDropdownField(
                  label: 'Gender',
                  hint: 'Select gender',
                  value: _gender,
                  items: HealthProfileOptions.genders,
                  onChanged: (v) => setState(() => _gender = v),
                  validator: (v) => _requiredSelection(v, 'Gender'),
                ),
                const SizedBox(height: 18),
                ProfileDropdownField(
                  label: 'Blood Type',
                  hint: 'Select blood type',
                  value: _bloodType,
                  items: HealthProfileOptions.bloodTypes,
                  onChanged: (v) => setState(() => _bloodType = v),
                  validator: (v) => _requiredSelection(v, 'Blood type'),
                ),
                const SizedBox(height: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      validator: _phoneLk,
                      decoration: InputDecoration(
                        hintText: '77 123 4567',
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 8),
                            const Icon(Icons.phone_outlined, color: AppColors.textGrey),
                            const SizedBox(width: 8),
                            Text('+94', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                            Container(
                              margin: const EdgeInsets.only(left: 10, right: 8),
                              width: 1,
                              height: 24,
                              color: const Color(0xFFDEE2E6),
                            ),
                          ],
                        ),
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
                  ],
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Email',
                  hint: 'yourname@example.com',
                  controller: _email,
                  validator: Validators.email,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 18),
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
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Create Account', onPressed: _submit),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Already have an account? ', style: TextStyle(color: Colors.grey.shade600)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
    if (_isDependentRegistration) return screen;
    return LoggedOutOnlyGate(child: screen);
  }
}
