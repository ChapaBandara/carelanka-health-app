import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _p = TextEditingController();
  final _c = TextEditingController();
  bool _o1 = true;
  bool _o2 = true;

  @override
  void dispose() {
    _p.dispose();
    _c.dispose();
    super.dispose();
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
                  label: 'Update Password',
                  onPressed: () async {
                    if (!(_formKey.currentState?.validate() ?? false)) return;
                    final auth = context.read<AuthProvider>();
                    await auth.bootstrap();
                    if (!context.mounted) return;
                    final route = auth.isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;
                    Navigator.pushNamedAndRemoveUntil(context, route, (_) => false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
