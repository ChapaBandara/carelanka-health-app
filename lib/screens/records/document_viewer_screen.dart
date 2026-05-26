import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class DocumentViewerScreen extends StatelessWidget {
  const DocumentViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Document'),
        centerTitle: true,
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined))],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              height: 420,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0E0E0)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 72, color: AppColors.errorRed.withValues(alpha: 0.85)),
                  const SizedBox(height: 16),
                  const Text('Lab Report — Oct 2025', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Preview is read-only', style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Download PDF'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
