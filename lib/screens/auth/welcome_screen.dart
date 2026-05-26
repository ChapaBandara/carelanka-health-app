import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/constants/app_strings.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/widgets/auth/logged_out_only_gate.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  void _clearDeletionState() {
    context.read<AuthProvider>().clearJustDeletedAccount();
  }

  Future<void> _openLogin() async {
    _clearDeletionState();
    final auth = context.read<AuthProvider>();
    await auth.bootstrap();
    if (!mounted) return;
    if (context.read<AuthProvider>().isLoggedIn) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
    } else {
      Navigator.pushNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return LoggedOutOnlyGate(
      child: Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: h * 0.38,
              width: double.infinity,
              decoration: BoxDecoration(gradient: CareLankaGradients.welcomeHeader),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                        ),
                        child: Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(28, 36, 28, 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Welcome to CareLanka',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 32),
                      GradientPrimaryButton(
                        label: 'Login',
                        onPressed: _openLogin,
                      ),
                      const SizedBox(height: 14),
                      GradientOutlinePillButton(
                        label: 'Create Account',
                        onPressed: () {
                          _clearDeletionState();
                          Navigator.pushNamed(context, AppRoutes.register);
                        },
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'By continuing you agree to our Terms and Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
