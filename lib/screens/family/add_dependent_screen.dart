import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/firebase/firebase_snackbar.dart';
import 'package:carelanka_app/providers/auth_provider.dart';
import 'package:carelanka_app/services/family_service.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddDependentScreen extends StatefulWidget {
  const AddDependentScreen({super.key});

  @override
  State<AddDependentScreen> createState() => _AddDependentScreenState();
}

class _AddDependentScreenState extends State<AddDependentScreen> {
  final _name = TextEditingController();
  final _rel = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _rel.dispose();
    super.dispose();
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Future<void> _save({bool createLogin = false}) async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter dependent name')));
      return;
    }
    final auth = context.read<AuthProvider>();
    final guardian = auth.profile?.fullName ?? 'Primary account';

    try {
      await FamilyService().addDependentProfile(
        ownerId: FirebaseAuth.instance.currentUser!.uid,
        fullName: _name.text.trim(),
        relationship: _rel.text.trim().isEmpty ? 'Dependent' : _rel.text.trim(),
      );
    } catch (e) {
      if (!mounted) return;
      showFirebaseErrorSnackBar(context, firebaseErrorMessage(e));
      return;
    }

    if (createLogin) {
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.register,
        arguments: {'isDependent': true, 'guardianName': guardian, 'prefillName': _name.text.trim()},
      );
      return;
    }

    if (!mounted) return;
    showFirebaseSuccessSnackBar(context, 'Dependent profile created');
    await showCareLankaSuccessNotification(
      context,
      title: 'Family member added',
      subtitle: 'You can now manage medications and records for this dependent profile.',
    );
    if (mounted) Navigator.pop(context);
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
        title: const Text('Create Dependent'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rel,
              decoration: const InputDecoration(labelText: 'Relationship (e.g. Child)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            GradientPrimaryButton(label: 'Create profile', onPressed: () => _save()),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _save(createLogin: true),
              child: const Text('Create profile with app login (dependent)'),
            ),
            const SizedBox(height: 8),
            Text(
              'Dependent logins only see their family link; health data is managed by the primary account.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.35),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
