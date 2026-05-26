import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class ConflictWarningCard extends StatelessWidget {
  final String type;
  final List<String> conflictList;
  const ConflictWarningCard({super.key, required this.type, required this.conflictList});

  @override
  Widget build(BuildContext context) {
    final isDrug = type == 'drug';
    final color = isDrug ? AppColors.errorRed : const Color(0xFFFF8C42);
    return Card(
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(isDrug ? Icons.warning_amber_rounded : Icons.health_and_safety, color: color), const SizedBox(width: 8), Text(isDrug ? 'Potential drug interaction' : 'Allergy alert', style: TextStyle(fontWeight: FontWeight.w600, color: color))]),
          const SizedBox(height: 8),
          ...conflictList.map((e) => Text('• $e')),
          const SizedBox(height: 8),
          const Text('Please consult your doctor before proceeding.', style: TextStyle(fontSize: 12)),
        ]),
      ),
    );
  }
}
