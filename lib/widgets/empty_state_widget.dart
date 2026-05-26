import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;

  const EmptyStateWidget({super.key, required this.icon, required this.title, required this.subtitle, this.buttonText, this.onButtonTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 64, color: AppColors.textGrey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: AppColors.textGrey), textAlign: TextAlign.center),
          if (buttonText != null && onButtonTap != null) ...[
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onButtonTap, child: Text(buttonText!)),
          ],
        ]),
      ),
    );
  }
}
