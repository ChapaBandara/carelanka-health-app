import 'package:carelanka_app/core/constants/app_colors.dart';
import 'package:carelanka_app/core/constants/app_routes.dart';
import 'package:carelanka_app/core/utils/active_uid.dart';
import 'package:carelanka_app/providers/family_provider.dart';
import 'package:carelanka_app/services/illness_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class IllnessListScreen extends StatelessWidget {
  const IllnessListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyProvider>(
      builder: (context, _, _) {
    final userId = context.activeScopeId;
    return StreamBuilder<List<Map<String, String>>>(
      stream: IllnessService().watchIllnessMaps(userId),
      builder: (context, snapshot) {
        return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('My Illnesses'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Illnesses are managed under My Medications.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.medicationList),
                child: const Text('Open My Medications'),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
      },
    );
  }
}
