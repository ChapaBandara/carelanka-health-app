import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/design/carelanka_gradients.dart';
import 'package:carelanka_app/widgets/carelanka/success_notification_overlay.dart';
import 'package:flutter/material.dart';

/// CareLanka UI #59 / #60 — Report a Problem form with success notification.
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String _issueType = 'App crash';

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final refId = '#CR${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    await showCareLankaSuccessNotification(
      context,
      title: 'Report Submitted!',
      subtitle: 'Ref ID: $refId. We will review your report within 24 hours.',
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => Navigator.maybePop(context)),
        title: const Text('Report a Problem', style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Issue Type', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _issueType,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'App crash', child: Text('App crash')),
                    DropdownMenuItem(value: 'Login issue', child: Text('Login issue')),
                    DropdownMenuItem(value: 'Data not saving', child: Text('Data not saving')),
                    DropdownMenuItem(value: 'Other', child: Text('Other')),
                  ],
                  onChanged: (v) => setState(() => _issueType = v ?? _issueType),
                ),
                const SizedBox(height: 18),
                const Text('Description', style: TextStyle(color: AppColors.textGrey, fontSize: 13)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _details,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Please describe the issue in detail...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) => (v == null || v.trim().length < 12) ? 'Please add a bit more detail' : null,
                ),
                const SizedBox(height: 18),
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F7F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryTeal, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.primaryTeal, size: 28),
                      SizedBox(height: 6),
                      Text('Attach Screenshot (Optional)', style: TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submit,
                    borderRadius: BorderRadius.circular(14),
                    child: Ink(
                      height: 52,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: CareLankaGradients.primaryHorizontal),
                      child: const Center(child: Text('Submit Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
