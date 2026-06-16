import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/utils/validators.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _nw = TextEditingController();
  final _cf = TextEditingController();
  bool o1 = true;
  bool o2 = true;
  bool o3 = true;

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No authenticated user found');
      }
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _cur.text.trim(),
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_nw.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed successfully'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _cur.dispose();
    _nw.dispose();
    _cf.dispose();
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
        title: const Text('Change Password'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                LabeledIconField(
                  label: 'Current password',
                  controller: _cur,
                  obscureText: o1,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(onPressed: () => setState(() => o1 = !o1), icon: Icon(o1 ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                  validator: Validators.password,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'New password',
                  controller: _nw,
                  obscureText: o2,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(onPressed: () => setState(() => o2 = !o2), icon: Icon(o2 ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                  validator: Validators.password,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Confirm new password',
                  controller: _cf,
                  obscureText: o3,
                  prefixIcon: Icons.lock_outline,
                  suffix: IconButton(onPressed: () => setState(() => o3 = !o3), icon: Icon(o3 ? Icons.visibility_off_outlined : Icons.visibility_outlined)),
                  validator: (v) => v != _nw.text ? 'Mismatch' : null,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Update password', onPressed: _updatePassword),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
