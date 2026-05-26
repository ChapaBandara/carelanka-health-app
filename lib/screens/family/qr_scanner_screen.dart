import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:flutter/material.dart';

class QrScannerScreen extends StatelessWidget {
  const QrScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Scan QR'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_scanner, size: 120, color: AppColors.primaryTeal),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.linkConfirmation),
              child: const Text('Simulate successful scan'),
            ),
          ],
        ),
      ),
    );
  }
}
