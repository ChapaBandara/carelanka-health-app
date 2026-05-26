import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/widgets/carelanka/gradient_buttons.dart';
import 'package:carelanka_app/widgets/carelanka/labeled_text_field.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:flutter/material.dart';

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _details = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await showCareLankaSuccessNotification(
      context,
      title: 'Report received',
      subtitle: 'Thank you for helping improve CareLanka. Our team will review your message.',
    );
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, AppRoutes.profile, (_) => false);
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
        title: const Text('Report a Problem'),
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
                LabeledIconField(
                  label: 'Subject',
                  controller: _subject,
                  prefixIcon: Icons.short_text,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                LabeledIconField(
                  label: 'Describe the issue',
                  controller: _details,
                  prefixIcon: Icons.feedback_outlined,
                  maxLines: 6,
                  validator: (v) => (v == null || v.length < 12) ? 'Please add a bit more detail' : null,
                ),
                const SizedBox(height: 28),
                GradientPrimaryButton(label: 'Submit report', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
