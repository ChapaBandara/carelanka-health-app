import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class EmptyListPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const EmptyListPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 48, color: AppColors.textGrey.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textGrey, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
