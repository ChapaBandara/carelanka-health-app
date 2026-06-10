import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/auth_notifications.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/services/email_otp_service.dart';
import 'package:carelanka_app/services/emailjs_send_service.dart';
import 'package:carelanka_app/services/password_reset_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VerifyResetCodeScreen extends StatefulWidget {
  const VerifyResetCodeScreen({super.key});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _nodes = List.generate(6, (_) => FocusNode());
  final _phoneResetService = PasswordResetService();
  final _emailOtpService = EmailOtpService.instance;
  bool _verifying = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? get _args {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      return Map<String, dynamic>.from(args);
    }
    return null;
  }

  bool get _isEmail => _args?['channel'] == 'email';
  String get _destination => _args?['destination'] as String? ?? '';
  String get _email => _args?['email'] as String? ?? '';
  String? get _verificationId => _args?['verificationId'] as String?;

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  Future<void> _verify() async {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }
    if (_verifying) return;

    setState(() => _verifying = true);
    try {
      if (_isEmail) {
        try {
          await _emailOtpService.verifyOtp(email: _email, code: _code);
        } on OtpIncorrectException {
          if (!mounted) return;
          showFirebaseErrorSnackBar(context, 'Incorrect code. Try again.');
          return;
        } on OtpExpiredException {
          if (!mounted) return;
          showFirebaseErrorSnackBar(context, 'Code expired. Please request a new one.');
          return;
        }
      } else {
        final verificationId = _verificationId;
        if (verificationId == null || verificationId.isEmpty) {
          throw Exception('SMS session expired. Request a new OTP.');
        }
        await _phoneResetService.verifyPhoneOtp(
          verificationId: verificationId,
          smsCode: _code,
          email: _email,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.setNewPassword,
        arguments: {
          'channel': _isEmail ? 'email' : 'phone',
          'email': _email,
        },
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    try {
      if (_isEmail) {
        final generatedOtp = await _emailOtpService.prepareOtp(_email);

        await EmailJsSendService.sendOtpEmail(
          toEmail: _email.trim(),
          otpCode: generatedOtp.toString(),
        );

        if (!mounted) return;
        await showCodeSentToEmailNotification(context);
      } else {
        if (!mounted) return;
        showFirebaseErrorSnackBar(
          context,
          'Go back and tap Send OTP again to resend the SMS code.',
        );
      }
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
        title: const Text('Verify Code'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primaryTeal,
                child: Icon(Icons.verified_user_outlined, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'Enter verification code',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _isEmail
                    ? 'We sent a 6-digit code to $_destination. Enter it below to continue.'
                    : 'We sent a 6-digit OTP to $_destination. Enter it below to continue.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, height: 1.45),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 48,
                    child: TextField(
                      controller: _controllers[i],
                      focusNode: _nodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                        ),
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: _resend, child: const Text('Resend code')),
              const SizedBox(height: 28),
              GradientPrimaryButton(
                label: _verifying ? 'Verifying...' : 'Verify',
                onPressed: _verifying ? null : _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
