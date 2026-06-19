import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/auth_notifications.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/services/auth_service.dart';
import 'package:carelanka_app/services/email_otp_service.dart';
import 'package:carelanka_app/services/emailjs_send_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _authService = AuthService();
  final _emailOtpService = EmailOtpService.instance;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!(_emailKey.currentState?.validate() ?? false) || _sending) return;
    setState(() => _sending = true);
    try {
      final destination = _email.text.trim();
      final generatedOtp = await _emailOtpService.prepareOtp(destination);

      var sentViaOtp = false;
      try {
        await EmailJsSendService.sendOtpEmail(
          toEmail: _email.text.trim(),
          otpCode: generatedOtp.toString(),
        );
        sentViaOtp = true;
      } catch (_) {
        // Fallback for misconfigured EmailJS service/template IDs.
        await _authService.sendPasswordResetEmail(destination);
      }

      if (!mounted) return;
      if (sentViaOtp) {
        await showCodeSentToEmailNotification(context);
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.verifyResetCode,
          arguments: {
            'destination': destination,
            'email': destination,
          },
        );
      } else {
        await showCareLankaSuccessNotification(
          context,
          title: 'Reset Email Sent',
          subtitle: 'Password reset email sent to your inbox. Please check your email.',
        );
        if (!mounted) return;
        Navigator.maybePop(context);
      }
    } catch (e) {
      if (!mounted) return;
      await showCareLankaErrorNotification(
        context,
        title: 'Reset Failed',
        subtitle: firebaseErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Reset Password'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
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
