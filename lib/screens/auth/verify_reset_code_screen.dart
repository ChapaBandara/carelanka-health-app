import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
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

  String get _code => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _nodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _nodes[index - 1].requestFocus();
    }
  }

  void _verify() {
    if (_code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }
    // Phase 1: accept any 6-digit code for UI flow
    Navigator.pushReplacementNamed(context, AppRoutes.setNewPassword);
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final isEmail = args is Map && args['channel'] == 'email';
    final destination = args is Map ? (args['destination'] as String? ?? '') : '';

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
                isEmail
                    ? 'We sent a 6-digit code to $destination. Enter it below to continue.'
                    : 'We sent a 6-digit OTP to $destination. Enter it below to continue.',
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
                      ),
                      onChanged: (v) => _onChanged(i, v),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () {}, child: const Text('Resend code')),
              const SizedBox(height: 28),
              GradientPrimaryButton(label: 'Verify', onPressed: _verify),
            ],
          ),
        ),
      ),
    );
  }
}
