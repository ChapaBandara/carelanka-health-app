import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:flutter/material.dart';

class FamilyDetailScreen extends StatelessWidget {
  const FamilyDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Sarah Johnson'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _statRow('Medications', '2'),
          _statRow('Records', '5'),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: () {}, child: const Text('Open dependent dashboard')),
          const SizedBox(height: 12),
          TextButton(onPressed: () {}, child: const Text('Remove link', style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
  }

  Widget _statRow(String k, String v) {
    return Card(
      child: ListTile(title: Text(k), trailing: Text(v, style: const TextStyle(fontWeight: FontWeight.w800))),
    );
  }
}
