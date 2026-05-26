import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class MedicationCard extends StatelessWidget {
  final Map<String, dynamic> medication;
  final VoidCallback onTap;
  final void Function(String value) onMenuSelected;
  const MedicationCard({super.key, required this.medication, required this.onTap, required this.onMenuSelected});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(backgroundColor: AppColors.secondaryTeal, child: Text((medication['name'] as String).substring(0,1))),
        title: Text(medication['name'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${medication['dosage']} - ${medication['frequency']}'),
        trailing: PopupMenuButton<String>(
          onSelected: onMenuSelected,
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'history', child: Text('View History')),
            PopupMenuItem(value: 'inactive', child: Text('Mark Inactive')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
