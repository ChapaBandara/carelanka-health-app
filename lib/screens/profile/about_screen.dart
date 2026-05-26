import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_strings.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('About CareLanka'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.monitor_heart_outlined, size: 64, color: AppColors.primaryTeal),
            const SizedBox(height: 16),
            Text(AppStrings.appName, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const Text('Version 1.0.0', style: TextStyle(color: AppColors.textGrey)),
            const SizedBox(height: 24),
            Text(AppStrings.disclaimer, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.5)),
          ],
        ),
      ),
    );
  }
}
