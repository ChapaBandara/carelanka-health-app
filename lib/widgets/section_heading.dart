import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class SectionHeading extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const SectionHeading({super.key, required this.title, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (actionText != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionText!, style: const TextStyle(color: AppColors.primaryTeal))),
      ],
    );
  }
}
