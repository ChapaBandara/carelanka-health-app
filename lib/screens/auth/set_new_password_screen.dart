import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/services/email_otp_service.dart' show EmailOtpService, OtpExpiredException;
import 'package:carelanka_app/services/password_reset_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:flutter/material.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _phoneResetService = PasswordResetService();
  final _emailOtpService = EmailOtpService.instance;
  bool _o1 = true;
  bool _o2 = true;
  bool _saving = false;

  @override
  void dispose() {
    _p.dispose();
    _c.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _args {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      return Map<String, dynamic>.from(args);
    }
    return null;
  }

  String get _email => _args?['email'] as String? ?? '';
  String get _channel => _args?['channel'] as String? ?? 'email';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Set New Password'),
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
                const SizedBox(height: 8),
                const Text(
                  'Choose a new password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Use at least 8 characters including a number.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                LabeledIconField(
                  label: 'New Password',
                  controller: _p,
                  validator: Validators.password,
                  obscureText: _o1,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _o1 = !_o1),
                    icon: Icon(_o1 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Confirm Password',
                  controller: _c,
                  validator: (v) => v != _p.text ? 'Passwords do not match' : null,
                  obscureText: _o2,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _o2 = !_o2),
                    icon: Icon(_o2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 32),
                GradientPrimaryButton(
                  label: _saving ? 'Updating...' : 'Update Password',
                  onPressed: _saving ? null : _updatePassword,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updatePassword() async {
    if (!(_formKey.currentState?.validate() ?? false) || _email.isEmpty) return;

    setState(() => _saving = true);
    try {
      if (_channel == 'email') {
        await _emailOtpService.completePasswordReset(
          email: _email,
          newPassword: _p.text,
        );
      } else {
        await _phoneResetService.completePasswordReset(
          email: _email,
          newPassword: _p.text,
          channel: _channel,
        );
      }
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'Password updated. You can sign in now.');
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
    } on OtpExpiredException {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, 'Code expired. Please request a new one.');
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
