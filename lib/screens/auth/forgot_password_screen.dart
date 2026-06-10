import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/auth_notifications.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/services/email_otp_service.dart';
import 'package:carelanka_app/services/emailjs_send_service.dart';
import 'package:carelanka_app/services/password_reset_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _phoneKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _phoneResetService = PasswordResetService();
  final _emailOtpService = EmailOtpService.instance;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  String? _phoneLk(String? value) {
    if (value == null || value.trim().isEmpty) return 'Phone is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 9) return 'Enter 9 digits';
    return null;
  }

  Future<void> _sendEmail() async {
    if (!(_emailKey.currentState?.validate() ?? false) || _sending) return;
    setState(() => _sending = true);
    try {
      final destination = _email.text.trim();
      final generatedOtp = await _emailOtpService.prepareOtp(destination);

      await EmailJsSendService.sendOtpEmail(
        toEmail: _email.text.trim(),
        otpCode: generatedOtp.toString(),
      );

      if (!mounted) return;
      await showCodeSentToEmailNotification(context);
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.verifyResetCode,
        arguments: {
          'channel': 'email',
          'destination': destination,
          'email': destination,
        },
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhone() async {
    if (!(_phoneKey.currentState?.validate() ?? false) || _sending) return;
    setState(() => _sending = true);
    try {
      final request = await _phoneResetService.sendPhoneOtp(_phone.text.trim());
      if (!mounted) return;
      showFirebaseSuccessSnackBar(context, 'OTP sent to ${request.phoneE164}');
      Navigator.pushNamed(
        context,
        AppRoutes.verifyResetCode,
        arguments: {
          'channel': 'phone',
          'destination': request.phoneE164,
          'email': request.email,
          'verificationId': request.verificationId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: const Text('Reset Password'),
              centerTitle: true,
              bottom: TabBar(
                indicatorColor: AppColors.navy,
                labelColor: AppColors.navy,
                unselectedLabelColor: AppColors.textGrey,
                indicatorWeight: 3,
                tabs: const [
                  Tab(text: 'Email'),
                  Tab(text: 'Phone'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _emailKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        const CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primaryTeal,
                          child: Icon(Icons.lock_outline, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Reset via email',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your email and we will send a 6-digit verification code.',
                          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        LabeledIconField(
                          label: 'Email Address',
                          hint: 'yourname@example.com',
                          controller: _email,
                          validator: Validators.email,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 28),
                        GradientPrimaryButton(
                          label: _sending ? 'Sending...' : 'Send verification code',
                          onPressed: _sending ? null : _sendEmail,
                        ),
                      ],
                    ),
                  ),
                ),
                SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _phoneKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 12),
                        const CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.primaryTeal,
                          child: Icon(Icons.phone_android, color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Reset via phone',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your registered mobile number to receive an OTP by SMS.',
                          style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        LabeledIconField(
                          label: 'Phone Number',
                          hint: '77 123 4567',
                          controller: _phone,
                          validator: _phoneLk,
                          prefixIcon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 28),
                        GradientPrimaryButton(
                          label: _sending ? 'Sending...' : 'Send OTP',
                          onPressed: _sending ? null : _sendPhone,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_sending)
          const ColoredBox(
            color: Color(0x33000000),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
