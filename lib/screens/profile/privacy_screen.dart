import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Privacy and Security'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SectionCard(
            title: 'Data storage',
            body: 'Your health data is encrypted in transit and at rest. Only you and explicitly linked family accounts can view records you choose to share.',
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Account security',
            body: 'Use a strong password and keep your device locked. You can sign out remotely from linked devices from this screen in a future update.',
          ),
          SizedBox(height: 12),
          _SectionCard(
            title: 'Sharing',
            body: 'QR linking requires both members to confirm. You can remove linked accounts at any time from Family Health.',
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  const _SectionCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(body, style: const TextStyle(color: AppColors.textGrey, height: 1.45)),
          ],
        ),
      ),
    );
  }
}
