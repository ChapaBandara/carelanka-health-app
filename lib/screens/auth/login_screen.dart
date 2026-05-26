import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/auth_notifications.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/core/utils/user_data_sync.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/providers/user_data_provider.dart';
import 'package:carelanka_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:carelanka_app/widgets/auth/logged_out_only_gate.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailOrPhone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailOrPhone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final authProvider = context.read<AuthProvider>();
    try {
      final email = await AuthService().resolveEmailForLogin(_emailOrPhone.text.trim());
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: _password.text,
      );
      if (!mounted) return;
      await showLoginSuccessNotification(context);
      if (!mounted) return;
      await authProvider.loadFromFirebase();
      if (!mounted) return;
      syncUserDataForProfile(context.read<UserDataProvider>(), authProvider.profile);
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.dashboard, (_) => false);
    } catch (e) {
      if (!mounted) return;
      await showLoginErrorNotification(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoggedOutOnlyGate(
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Welcome Back'),
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
                const SizedBox(height: 8),
                const Text(
                  'Sign in to CareLanka',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your credentials to continue',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                LabeledIconField(
                  label: 'Email / Phone Number',
                  hint: 'Enter email or phone',
                  controller: _emailOrPhone,
                  validator: Validators.emailOrPhone,
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Password',
                  controller: _password,
                  validator: Validators.password,
                  obscureText: _obscure,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    color: AppColors.textGrey,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                    child: const Text('Forgot Password?', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                GradientPrimaryButton(label: 'Login', onPressed: _submit),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Don't have an account? ", style: TextStyle(color: Colors.grey.shade600)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
