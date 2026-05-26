import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class LinkConfirmationScreen extends StatelessWidget {
  const LinkConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Confirm link'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link, size: 56, color: AppColors.primaryTeal),
              const SizedBox(height: 16),
              const Text('Link with Nimali Mendis?', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                  const SizedBox(width: 12),
                  Expanded(child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Confirm'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
