import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('My QR Code'),
        centerTitle: true,
      ),
      body: const Center(child: Icon(Icons.qr_code_2, size: 220, color: AppColors.textDark)),
    );
  }
}
