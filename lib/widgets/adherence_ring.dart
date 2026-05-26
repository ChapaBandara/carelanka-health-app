import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class AdherenceRing extends StatelessWidget {
  final double percentage;
  final double size;
  const AdherenceRing({super.key, required this.percentage, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final value = (percentage / 100).clamp(0, 1);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(alignment: Alignment.center, children: [
        CircularProgressIndicator(value: value.toDouble(), strokeWidth: 7, color: AppColors.primaryTeal),
        Text('${percentage.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}
